/* Freetype GL - A C OpenGL Freetype engine
 *
 * Distributed under the OSI-approved BSD 2-Clause License.  See accompanying
 * file `LICENSE` for more details.
 */

vertexBuffer!vertex(
    format : 'string
    indices : array!i32()
    vertices : array!vertex()
    --cvar--
    vertex_buffer_t* buffer;
    --cvar--

    addIndex(index : 'i32) {
        --c--
        vertex_buffer_push_back_indices(_parent->buffer, &index, 1);
        --c--
        void
    }

    getVertexSize()'i32 {
        size := 0
        --c--
        size = _this->buffer->vertices->size;
        --c--
        size
    }

    addVertex(vertex : 'vertex) {
        --c--
        int vertexsize;
        #functionStack(vertex, getRawSize)(&vertexsize);
        char* t = malloc(vertexsize);
        char* buffer = t;
        #functionStack(vertex, rawCopy)(vertex, buffer, (void*)&buffer);
        vertex_buffer_push_back_vertices(_parent->buffer, t, 1);
        free(t);
        --c--
        void
    }

    translateScreenToTexture(screen : 'point, viewport : 'rect, projection : 'mat4, view : 'mat4, world : 'mat4)'vec2? {
        intersection := empty'vec3
        texture := empty'vec2

        // Compute the vector of the pick ray in screen space
        start : vec2(
            (screen.x - viewport.x) as f32 / viewport.w as f32 * 2.0f - 1.0f
            1.0f - (screen.y - viewport.y) as f32 / viewport.h as f32 * 2.0f)

        vScreenOrigin1 : vec4(start.x, start.y, 0.0f, 1.0f)
        vScreenOrigin2 : vec4(start.x, start.y, 1.0f, 1.0f)
        all : projection * view * world
        allInverse : all.invert()
        vProjectedOrigin1 : allInverse * vScreenOrigin1
        vProjectedOrigin2 : allInverse * vScreenOrigin2
        vFlattenedOrigin1 : vec3(vProjectedOrigin1.x / vProjectedOrigin1.w, vProjectedOrigin1.y / vProjectedOrigin1.w, vProjectedOrigin1.z / vProjectedOrigin1.w)
        vFlattenedOrigin2 : vec3(vProjectedOrigin2.x / vProjectedOrigin2.w, vProjectedOrigin2.y / vProjectedOrigin2.w, vProjectedOrigin2.z / vProjectedOrigin2.w)
        vFlattenedDir : vFlattenedOrigin2 - vFlattenedOrigin1

        vPickRayOrig : vFlattenedOrigin1
        vPickRayDir : vFlattenedDir.normalize()

        cTriangles : if indices.count > 0 { indices.count / 3 } else { vertices.count / 3 }
        for i : 0 to cTriangles {
            vertex0 : if indices.count > 0 { vertices[indices[i * 3 + 0]] } else { vertices[i * 3 + 0] }
            vertex1 : if indices.count > 0 { vertices[indices[i * 3 + 1]] } else { vertices[i * 3 + 1] }
            vertex2 : if indices.count > 0 { vertices[indices[i * 3 + 2]] } else { vertices[i * 3 + 2] }

            // Check if the pick ray passes through this point
            result : intersectTriangle(vPickRayOrig, vPickRayDir, vertex0.location, vertex1.location, vertex2.location)
            ifValid result {
                if isEmpty(intersection) || result.z < intersection?.z?:0.0f {
                    intersection = valid(result)                    
                    
                    // If all you want is the vertices hit, then you are done.  In this sample, we
                    // want to show how to infer texture coordinates as well, using the BaryCentric
                    // coordinates supplied by D3DXIntersect
                    dtu1 : vertex1.texture.x - vertex0.texture.x;
                    dtu2 : vertex2.texture.x - vertex0.texture.x;
                    dtv1 : vertex1.texture.y - vertex0.texture.y;
                    dtv2 : vertex2.texture.y - vertex0.texture.y;
                    texture = valid(vec2(
                        x: vertex0.texture.x + result.x * dtu1 + result.y * dtu2
                        y: vertex0.texture.y + result.x * dtv1 + result.y * dtv2))
                }
            }
        }

        texture
    }

    render(glDrawMode : 'glDrawMode)'void {
        --c--
        vertex_buffer_render(_parent->buffer, gldrawmode);
        --c--
        void
    }
) { 
    --c--
    _this->buffer = vertex_buffer_new((char*)_this->format.data.data);
    if (_this->indices.count > 0) {
        vertex_buffer_push_back_indices(_this->buffer, (GLuint*)_this->indices.data, _this->indices.count);
    }

    if (_this->vertices.count > 0) {
        int vertexSize;
        #functionStack(vertex, getRawSize)(&vertexSize);
        int verticesSize = _this->vertices.count * vertexSize;
        char* t = malloc(verticesSize);
        char* buffer = t;
        #type(vertex)* p = (#type(vertex)*)_this->vertices.data;
        for (int i = 0; i < _this->vertices.count; i++) {
            #functionStack(vertex, rawCopy)(&p[i], buffer, (void*)&buffer);
        }
        vertex_buffer_push_back_vertices(_this->buffer, t, _this->vertices.count);
        free(t);
    }
    --c--
    this 
} copy {
    --c--
    _this->buffer = _from->buffer;
    ptr_retain(_this->buffer);
    --c--
} destroy {
    --c--
    if (ptr_release(_this->buffer)) {
        vertex_buffer_delete(_this->buffer);  
    }
    --c--
}

intersectTriangle(orig : 'vec3, dir : 'vec3, v0 : 'vec3, v1 : 'vec3, v2 : 'vec3)'vec3? {
    // Find vectors for two edges sharing vert0
    edge1 : v1 - v0
    edge2 : v2 - v0
    pvec : dir.cross(edge2)
    det := edge1.dot(pvec)
    tvec : if det > 0.0f {
            orig - v0
        } else {
            det = 0.0f - det
            v0 - orig
        }

    if det < 0.0001f {
        empty'vec3
    } else {
        u : tvec.dot(pvec)
        if u < 0.0f || u > det {
            empty'vec3
        } else {
            qvec : tvec.cross(edge1)
            v : dir.dot(qvec)
            if v < 0.0f || u + v > det {
                empty'vec3
            } else {
                // Calculate t, scale parameters, ray intersects triangle
                t : edge2.dot(qvec)
                fInvDet : 1.0f / det
                valid(vec3(u * fInvDet, v * fInvDet, t * fInvDet))
            }
        }
    }
}

--ctypedef--
typedef struct vertex_buffer_td vertex_buffer_t;
--ctypedef--

--cstruct--
/**
 * Generic vertex buffer.
 */
struct vertex_buffer_td
{
    /** Format of the vertex buffer. */
    char * format;

    /** Vector of vertices. */
    vector_t * vertices;

##ifdef FREETYPE_GL_USE_VAO
    /** GL identity of the Vertex Array Object */
    GLuint VAO_id;
##endif

    /** GL identity of the vertices buffer. */
    GLuint vertices_id;

    /** Vector of indices. */
    vector_t * indices;

    /** GL identity of the indices buffer. */
    GLuint indices_id;

    /** Current size of the vertices buffer in GPU */
    size_t GPU_vsize;

    /** Current size of the indices buffer in GPU*/
    size_t GPU_isize;

    /** GL primitives to render. */
    GLenum mode;

    /** Whether the vertex buffer needs to be uploaded to GPU memory. */
    char state;

    /** Individual items */
    vector_t * items;

    /** Array of attributes. */
    vertex_attribute_t *attributes[MAX_VERTEX_ATTRIBUTE];
};
--cstruct--

--cdefine--
##ifdef WIN32
// strndup() is not available on Windows
char *strndup( const char *s1, size_t n);
##endif

/**
 * Creates an empty vertex buffer.
 *
 * @param  format a string describing vertex format.
 * @return        an empty vertex buffer.
 */
  vertex_buffer_t *
  vertex_buffer_new( const char *format );


/**
 * Deletes vertex buffer and releases GPU memory.
 *
 * @param  self  a vertex buffer
 */
  void
  vertex_buffer_delete( vertex_buffer_t * self );


/**
 *  Returns the number of items in the vertex buffer
 *
 *  @param  self  a vertex buffer
 *  @return       number of items
 */
  size_t
  vertex_buffer_size( const vertex_buffer_t *self );


/**
 *  Returns vertex format
 *
 *  @param  self  a vertex buffer
 *  @return       vertex format
 */
  const char *
  vertex_buffer_format( const vertex_buffer_t *self );


/**
 * Print information about a vertex buffer
 *
 * @param  self  a vertex buffer
 */
  void
  vertex_buffer_print( vertex_buffer_t * self );


/**
 * Prepare vertex buffer for render.
 *
 * @param  self  a vertex buffer
 * @param  mode  render mode
 */
  void
  vertex_buffer_render_setup ( vertex_buffer_t *self,
                               GLenum mode );


/**
 * Finish rendering by setting back modified states
 *
 * @param  self  a vertex buffer
 */
  void
  vertex_buffer_render_finish ( vertex_buffer_t *self );


/**
 * Render vertex buffer.
 *
 * @param  self  a vertex buffer
 * @param  mode  render mode
 */
  void
  vertex_buffer_render ( vertex_buffer_t *self,
                         GLenum mode );


/**
 * Render a specified item from the vertex buffer.
 *
 * @param  self   a vertex buffer
 * @param  index index of the item to be rendered
 */
  void
  vertex_buffer_render_item ( vertex_buffer_t *self,
                              size_t index );


/**
 * Upload buffer to GPU memory.
 *
 * @param  self  a vertex buffer
 */
  void
  vertex_buffer_upload( vertex_buffer_t *self );


/**
 * Clear all items.
 *
 * @param  self  a vertex buffer
 */
  void
  vertex_buffer_clear( vertex_buffer_t *self );


/**
 * Appends indices at the end of the buffer.
 *
 * @param  self     a vertex buffer
 * @param  indices  indices to be appended
 * @param  icount   number of indices to be appended
 *
 * @private
 */
  void
  vertex_buffer_push_back_indices ( vertex_buffer_t *self,
                                    const GLuint * indices,
                                    const size_t icount );


/**
 * Appends vertices at the end of the buffer.
 *
 * @note Internal use
 *
 * @param  self     a vertex buffer
 * @param  vertices vertices to be appended
 * @param  vcount   number of vertices to be appended
 *
 * @private
 */
  void
  vertex_buffer_push_back_vertices ( vertex_buffer_t *self,
                                     const void * vertices,
                                     const size_t vcount );


/**
 * Insert indices in the buffer.
 *
 * @param  self    a vertex buffer
 * @param  index   location before which to insert indices
 * @param  indices indices to be appended
 * @param  icount  number of indices to be appended
 *
 * @private
 */
  void
  vertex_buffer_insert_indices ( vertex_buffer_t *self,
                                 const size_t index,
                                 const GLuint *indices,
                                 const size_t icount );


/**
 * Insert vertices in the buffer.
 *
 * @param  self     a vertex buffer
 * @param  index    location before which to insert vertices
 * @param  vertices vertices to be appended
 * @param  vcount   number of vertices to be appended
 *
 * @private
 */
  void
  vertex_buffer_insert_vertices ( vertex_buffer_t *self,
                                  const size_t index,
                                  const void *vertices,
                                  const size_t vcount );

/**
 * Erase indices in the buffer.
 *
 * @param  self   a vertex buffer
 * @param  first  the index of the first index to be erased
 * @param  last   the index of the last index to be erased
 *
 * @private
 */
  void
  vertex_buffer_erase_indices ( vertex_buffer_t *self,
                                const size_t first,
                                const size_t last );

/**
 * Erase vertices in the buffer.
 *
 * @param  self   a vertex buffer
 * @param  first  the index of the first vertex to be erased
 * @param  last   the index of the last vertex to be erased
 *
 * @private
 */
  void
  vertex_buffer_erase_vertices ( vertex_buffer_t *self,
                                 const size_t first,
                                 const size_t last );


/**
 * Append a new item to the collection.
 *
 * @param  self   a vertex buffer
 * @param  vcount   number of vertices
 * @param  vertices raw vertices data
 * @param  icount   number of indices
 * @param  indices  raw indices data
 */
  size_t
  vertex_buffer_push_back( vertex_buffer_t * self,
                           const void * vertices, const size_t vcount,
                           const GLuint * indices, const size_t icount );


/**
 * Insert a new item into the vertex buffer.
 *
 * @param  self      a vertex buffer
 * @param  index     location before which to insert item
 * @param  vertices  raw vertices data
 * @param  vcount    number of vertices
 * @param  indices   raw indices data
 * @param  icount    number of indices
 */
  size_t
  vertex_buffer_insert( vertex_buffer_t * self,
                        const size_t index,
                        const void * vertices, const size_t vcount,
                        const GLuint * indices, const size_t icount );

/**
 * Erase an item from the vertex buffer.
 *
 * @param  self     a vertex buffer
 * @param  index    index of the item to be deleted
 */
  void
  vertex_buffer_erase( vertex_buffer_t * self,
                       const size_t index );    
--cdefine--

--cfunction--
#include(<assert.h>)
#include(<string.h>)
#include(<stdlib.h>)
#include(<stdio.h>)

##ifdef WIN32
// strndup() is not available on Windows
char *strndup( const char *s1, size_t n)
{
    char *copy= (char*)malloc( n+1 );
    memcpy( copy, s1, n );
    copy[n] = 0;
    return copy;
};
##endif

/**
 * Buffer status
 */
##define CLEAN  (0)
##define DIRTY  (1)
##define FROZEN (2)


// ----------------------------------------------------------------------------
vertex_buffer_t *
vertex_buffer_new( const char *format )
{
    size_t i, index = 0, stride = 0;
    const char *start = 0, *end = 0;
    GLchar *pointer = 0;

    vertex_buffer_t *self = (vertex_buffer_t *) malloc (sizeof(vertex_buffer_t));
    if( !self )
    {
        return NULL;
    }

    self->format = strdup( format );

    for( i=0; i<MAX_VERTEX_ATTRIBUTE; ++i )
    {
        self->attributes[i] = 0;
    }

    start = format;
    do
    {
        char *desc = 0;
        vertex_attribute_t *attribute;
        GLuint attribute_size = 0;
        end = (char *) (strchr(start+1, ','));

        if (end == NULL)
        {
            desc = strdup( start );
        }
        else
        {
            desc = strndup( start, end-start );
        }
        attribute = vertex_attribute_parse( desc );
        start = end+1;
        free(desc);
        attribute->pointer = pointer;

        switch( attribute->type )
        {
        case GL_BOOL:           attribute_size = sizeof(GLboolean); break;
        case GL_BYTE:           attribute_size = sizeof(GLbyte); break;
        case GL_UNSIGNED_BYTE:  attribute_size = sizeof(GLubyte); break;
        case GL_SHORT:          attribute_size = sizeof(GLshort); break;
        case GL_UNSIGNED_SHORT: attribute_size = sizeof(GLushort); break;
        case GL_INT:            attribute_size = sizeof(GLint); break;
        case GL_UNSIGNED_INT:   attribute_size = sizeof(GLuint); break;
        case GL_FLOAT:          attribute_size = sizeof(GLfloat); break;
        default:                attribute_size = 0;
        }
        stride  += attribute->size*attribute_size;
        pointer += attribute->size*attribute_size;
        self->attributes[index] = attribute;
        index++;
    } while ( end && (index < MAX_VERTEX_ATTRIBUTE) );

    for( i=0; i<index; ++i )
    {
        self->attributes[i]->stride = (GLsizei)stride;
    }

##ifdef FREETYPE_GL_USE_VAO
    self->VAO_id = 0;
##endif

    self->vertices = vector_new( stride );
    self->vertices_id  = 0;
    self->GPU_vsize = 0;

    self->indices = vector_new( sizeof(GLuint) );
    self->indices_id  = 0;
    self->GPU_isize = 0;

    self->items = vector_new( sizeof(ivec4) );
    self->state = DIRTY;
    self->mode = GL_TRIANGLES;
    return self;
}



// ----------------------------------------------------------------------------
void
vertex_buffer_delete( vertex_buffer_t *self )
{
    size_t i;

    assert( self );

    for( i=0; i<MAX_VERTEX_ATTRIBUTE; ++i )
    {
        if( self->attributes[i] )
        {
            vertex_attribute_delete( self->attributes[i] );
        }
    }

##ifdef FREETYPE_GL_USE_VAO
    if( self->VAO_id )
    {
        glDeleteVertexArrays( 1, &self->VAO_id );
    }
    self->VAO_id = 0;
##endif

    vector_delete( self->vertices );
    self->vertices = 0;
    if( self->vertices_id )
    {
        glDeleteBuffers( 1, &self->vertices_id );
    }
    self->vertices_id = 0;

    vector_delete( self->indices );
    self->indices = 0;
    if( self->indices_id )
    {
        glDeleteBuffers( 1, &self->indices_id );
    }
    self->indices_id = 0;

    vector_delete( self->items );

    if( self->format )
    {
        free( self->format );
    }
    self->format = 0;
    self->state = 0;
    free( self );
}


// ----------------------------------------------------------------------------
const char *
vertex_buffer_format( const vertex_buffer_t *self )
{
    assert( self );

    return self->format;
}


// ----------------------------------------------------------------------------
size_t
vertex_buffer_size( const vertex_buffer_t *self )
{
    assert( self );

    return vector_size( self->items );
}


// ----------------------------------------------------------------------------
void
vertex_buffer_print( vertex_buffer_t * self )
{
    int i = 0;
    static char *gltypes[9] = {
        "GL_BOOL",
        "GL_BYTE",
        "GL_UNSIGNED_BYTE",
        "GL_SHORT",
        "GL_UNSIGNED_SHORT",
        "GL_INT",
        "GL_UNSIGNED_INT",
        "GL_FLOAT",
        "GL_VOID"
    };

    assert(self);

    fprintf( stderr, "%d vertices, %d indices\n",
             (int)vector_size( self->vertices ), (int)vector_size( self->indices ) );
    while( self->attributes[i] )
    {
        int j = 8;
        switch( self->attributes[i]->type )
        {
        case GL_BOOL:           j=0; break;
        case GL_BYTE:           j=1; break;
        case GL_UNSIGNED_BYTE:  j=2; break;
        case GL_SHORT:          j=3; break;
        case GL_UNSIGNED_SHORT: j=4; break;
        case GL_INT:            j=5; break;
        case GL_UNSIGNED_INT:   j=6; break;
        case GL_FLOAT:          j=7; break;
        default:                j=8; break;
        }
        fprintf(stderr, "%s : %dx%s (+%p)\n",
                self->attributes[i]->name,
                self->attributes[i]->size,
                gltypes[j],
                self->attributes[i]->pointer);

        i += 1;
    }
}


// ----------------------------------------------------------------------------
void
vertex_buffer_upload ( vertex_buffer_t *self )
{
    size_t vsize, isize;

    if( self->state == FROZEN )
    {
        return;
    }

    if( !self->vertices_id )
    {
        glGenBuffers( 1, &self->vertices_id );
    }
    if( !self->indices_id )
    {
        glGenBuffers( 1, &self->indices_id );
    }

    vsize = self->vertices->size*self->vertices->item_size;
    isize = self->indices->size*self->indices->item_size;


    // Always upload vertices first such that indices do not point to non
    // existing data (if we get interrupted in between for example).

    // Upload vertices
    glBindBuffer( GL_ARRAY_BUFFER, self->vertices_id );
    if( vsize != self->GPU_vsize )
    {
        glBufferData( GL_ARRAY_BUFFER,
                      vsize, self->vertices->items, GL_DYNAMIC_DRAW );
        self->GPU_vsize = vsize;
    }
    else
    {
        glBufferSubData( GL_ARRAY_BUFFER,
                         0, vsize, self->vertices->items );
    }
    glBindBuffer( GL_ARRAY_BUFFER, 0 );

    // Upload indices
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, self->indices_id );
    if( isize != self->GPU_isize )
    {
        glBufferData( GL_ELEMENT_ARRAY_BUFFER,
                      isize, self->indices->items, GL_DYNAMIC_DRAW );
        self->GPU_isize = isize;
    }
    else
    {
        glBufferSubData( GL_ELEMENT_ARRAY_BUFFER,
                         0, isize, self->indices->items );
    }
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, 0 );
}



// ----------------------------------------------------------------------------
void
vertex_buffer_clear( vertex_buffer_t *self )
{
    assert( self );

    self->state = FROZEN;
    vector_clear( self->indices );
    vector_clear( self->vertices );
    vector_clear( self->items );
    self->state = DIRTY;
}



// ----------------------------------------------------------------------------
void
vertex_buffer_render_setup ( vertex_buffer_t *self, GLenum mode )
{
    size_t i;

##ifdef FREETYPE_GL_USE_VAO
    // Unbind so no existing VAO-state is overwritten,
    // (e.g. the GL_ELEMENT_ARRAY_BUFFER-binding).
    glBindVertexArray( 0 );
##endif

    if( self->state != CLEAN )
    {
        vertex_buffer_upload( self );
        self->state = CLEAN;
    }

##ifdef FREETYPE_GL_USE_VAO
    if( self->VAO_id == 0 )
    {
        // Generate and set up VAO

        glGenVertexArrays( 1, &self->VAO_id );
        glBindVertexArray( self->VAO_id );

        glBindBuffer( GL_ARRAY_BUFFER, self->vertices_id );

        for( i=0; i<MAX_VERTEX_ATTRIBUTE; ++i )
        {
            vertex_attribute_t *attribute = self->attributes[i];
            if( attribute == 0 )
            {
                continue;
            }
            else
            {
                vertex_attribute_enable( attribute );
            }
        }

        glBindBuffer( GL_ARRAY_BUFFER, 0 );

        if( self->indices->size )
        {
            glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, self->indices_id );
        }
    }

    // Bind VAO for drawing
    glBindVertexArray( self->VAO_id );
##else

    glBindBuffer( GL_ARRAY_BUFFER, self->vertices_id );

    for( i=0; i<MAX_VERTEX_ATTRIBUTE; ++i )
    {
        vertex_attribute_t *attribute = self->attributes[i];
        if ( attribute == 0 )
        {
            continue;
        }
        else
        {
            vertex_attribute_enable( attribute );
        }
    }

    if( self->indices->size )
    {
        glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, self->indices_id );
    }
##endif

    self->mode = mode;
}

// ----------------------------------------------------------------------------
void
vertex_buffer_render_finish ( vertex_buffer_t *self )
{
##ifdef FREETYPE_GL_USE_VAO
    glBindVertexArray( 0 );
##else
    int i;

    for( i=0; i<MAX_VERTEX_ATTRIBUTE; ++i )
    {
        vertex_attribute_t *attribute = self->attributes[i];
        if( attribute == 0 )
        {
            continue;
        }
        else
        {
            glDisableVertexAttribArray( attribute->index );
        }
    }

    glBindBuffer( GL_ARRAY_BUFFER, 0 );
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, 0 );
##endif
}


// ----------------------------------------------------------------------------
void
vertex_buffer_render_item ( vertex_buffer_t *self,
                            size_t index )
{
    ivec4 * item = (ivec4 *) vector_get( self->items, index );
    assert( self );
    assert( index < vector_size( self->items ) );


    if( self->indices->size )
    {
        size_t start = item->istart;
        size_t count = item->icount;
        glDrawElements( self->mode, (GLint)count, GL_UNSIGNED_INT, (void *)(start*sizeof(GLuint)) );
    }
    else if( self->vertices->size )
    {
        size_t start = item->vstart;
        size_t count = item->vcount;
        glDrawArrays( self->mode, (GLint)(start*self->vertices->item_size), (GLint)count);
    }
}


// ----------------------------------------------------------------------------
void
vertex_buffer_render ( vertex_buffer_t *self, GLenum mode )
{
    size_t vcount = self->vertices->size;
    size_t icount = self->indices->size;

    vertex_buffer_render_setup( self, mode );
    if( icount )
    {
        glDrawElements( mode, (GLint)icount, GL_UNSIGNED_INT, 0 );
    }
    else
    {
        glDrawArrays( mode, 0, (GLint)vcount );
    }
    vertex_buffer_render_finish( self );
}



// ----------------------------------------------------------------------------
void
vertex_buffer_push_back_indices ( vertex_buffer_t * self,
                                  const GLuint * indices,
                                  const size_t icount )
{
    assert( self );

    self->state |= DIRTY;
    vector_push_back_data( self->indices, indices, icount );
}



// ----------------------------------------------------------------------------
void
vertex_buffer_push_back_vertices ( vertex_buffer_t * self,
                                   const void * vertices,
                                   const size_t vcount )
{
    assert( self );

    self->state |= DIRTY;
    vector_push_back_data( self->vertices, vertices, vcount );
}



// ----------------------------------------------------------------------------
void
vertex_buffer_insert_indices ( vertex_buffer_t *self,
                               const size_t index,
                               const GLuint *indices,
                               const size_t count )
{
    assert( self );
    assert( self->indices );
    assert( index < self->indices->size+1 );

    self->state |= DIRTY;
    vector_insert_data( self->indices, index, indices, count );
}



// ----------------------------------------------------------------------------
void
vertex_buffer_insert_vertices( vertex_buffer_t *self,
                               const size_t index,
                               const void *vertices,
                               const size_t vcount )
{
    size_t i;
    assert( self );
    assert( self->vertices );
    assert( index < self->vertices->size+1 );

    self->state |= DIRTY;

     for( i=0; i<self->indices->size; ++i )
    {
        if( *(GLuint *)(vector_get( self->indices, i )) > index )
        {
            *(GLuint *)(vector_get( self->indices, i )) += index;
        }
    }

    vector_insert_data( self->vertices, index, vertices, vcount );
}



// ----------------------------------------------------------------------------
void
vertex_buffer_erase_indices( vertex_buffer_t *self,
                             const size_t first,
                             const size_t last )
{
    assert( self );
    assert( self->indices );
    assert( first < self->indices->size );
    assert( (last) <= self->indices->size );

    self->state |= DIRTY;
    vector_erase_range( self->indices, first, last );
}



// ----------------------------------------------------------------------------
void
vertex_buffer_erase_vertices( vertex_buffer_t *self,
                              const size_t first,
                              const size_t last )
{
    size_t i;
    assert( self );
    assert( self->vertices );
    assert( first < self->vertices->size );
    assert( last <= self->vertices->size );
    assert( last > first );

    self->state |= DIRTY;
    for( i=0; i<self->indices->size; ++i )
    {
        if( *(GLuint *)(vector_get( self->indices, i )) > first )
        {
            *(GLuint *)(vector_get( self->indices, i )) -= (last-first);
        }
    }
    vector_erase_range( self->vertices, first, last );
}



// ----------------------------------------------------------------------------
size_t
vertex_buffer_push_back( vertex_buffer_t * self,
                         const void * vertices, const size_t vcount,
                         const GLuint * indices, const size_t icount )
{
    return vertex_buffer_insert( self, vector_size( self->items ),
                                 vertices, vcount, indices, icount );
}

// ----------------------------------------------------------------------------
size_t
vertex_buffer_insert( vertex_buffer_t * self, const size_t index,
                      const void * vertices, const size_t vcount,
                      const GLuint * indices, const size_t icount )
{
    size_t vstart, istart, i;
    ivec4 item;
    assert( self );
    assert( vertices );
    assert( indices );

    self->state = FROZEN;

    // Push back vertices
    vstart = vector_size( self->vertices );
    vertex_buffer_push_back_vertices( self, vertices, vcount );

    // Push back indices
    istart = vector_size( self->indices );
    vertex_buffer_push_back_indices( self, indices, icount );

    // Update indices within the vertex buffer
    for( i=0; i<icount; ++i )
    {
        *(GLuint *)(vector_get( self->indices, istart+i )) += vstart;
    }

    // Insert item
    item.x = (int)vstart;
    item.y = (int)vcount;
    item.z = (int)istart;
    item.w = (int)icount;
    vector_insert( self->items, index, &item );

    self->state = DIRTY;
    return index;
}

// ----------------------------------------------------------------------------
void
vertex_buffer_erase( vertex_buffer_t * self,
                     const size_t index )
{
    ivec4 * item;
    int vstart;
    size_t vcount, istart, icount, i;

    assert( self );
    assert( index < vector_size( self->items ) );

    item = (ivec4 *) vector_get( self->items, index );
    vstart = item->vstart;
    vcount = item->vcount;
    istart = item->istart;
    icount = item->icount;

    // Update items
    for( i=0; i<vector_size(self->items); ++i )
    {
        ivec4 * item = (ivec4 *) vector_get( self->items, i );
        if( item->vstart > vstart)
        {
            item->vstart -= vcount;
            item->istart -= icount;
        }
    }

    self->state = FROZEN;
    vertex_buffer_erase_indices( self, istart, istart+icount );
    vertex_buffer_erase_vertices( self, vstart, vstart+vcount );
    vector_erase( self->items, index );
    self->state = DIRTY;
}


--cfunction--