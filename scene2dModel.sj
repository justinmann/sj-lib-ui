@heap
scene2dModel #model (
    id : empty'string
    vertexBuffer : 'vertexBuffer!vertex_location_texture_normal
    shader : 'shader
    textureSize : size(512, 512)
    children : array!heap #element()
    hasAlpha : false
    center : vec3()
    model := mat4_identity()
    _innerScene : scene2d()
    _sceneRect := rect()
    _projection := mat4()
    _world := mat4()
    _view := mat4()
    _light := light()
    _projectedCenter := vec4()
    _framebuffer := framebuffer()
    _texture := texture()
    _renderbuffer := renderbuffer()

    update(sceneRect : 'rect, projection : 'mat4, view : 'mat4, world : 'mat4, light : 'light)'void {
        _sceneRect = sceneRect
        _projection = projection
        _view = view
        _world = world
        _light = light
        _projectedCenter = (_projection * _view * _world * model * vec4(center.x, center.y, center.z, 1.0f))
        void
    }

    getZ() { _projectedCenter.z }
    getCenter() { center }
    getWorld() { _world * model }

    renderOrQueue(alphaModels : 'list!heap #model) {
        if hasAlpha {
            alphaModels.add(parent as #model)
        } else {
            render()
        }
    }

    render()'void {
        glPushFramebuffer(_framebuffer)

        _innerScene.start()
        for i : 0 to children.count {
            child : children[i]
            child.render(_innerScene)
        }
        _innerScene.end()

        glPopFramebuffer(_framebuffer)

        glEnable(glFeature.GL_DEPTH_TEST)
        viewWorld : _view * _world * model
        normalMat : viewWorld.invert().transpose()
        glUseProgram(shader)
        glBlendFunc(glBlendFuncType.GL_SRC_ALPHA, glBlendFuncType.GL_ONE_MINUS_SRC_ALPHA)
        glBindTexture(glTexture.GL_TEXTURE_2D, _texture)
        glUniformMat4(glGetUniformLocation(shader, "viewModel"), viewWorld)
        glUniformMat4(glGetUniformLocation(shader, "normalMat"), normalMat)
        glUniformMat4(glGetUniformLocation(shader, "projection"), _projection)
        glUniformVec3(glGetUniformLocation(shader, "lightPos"), _light.pos)
        glUniformVec3(glGetUniformLocation(shader, "diffuseColor"), _light.diffuseColor.asVec3())
        glUniformVec3(glGetUniformLocation(shader, "specColor"), _light.specColor.asVec3())
        vertexBuffer.render(glDrawMode.GL_TRIANGLES)
    }

    fireMouseEvent(mouseEvent : 'mouseEvent)'void {
        texture : vertexBuffer.translateScreenToTexture(mouseEvent.point, _sceneRect, _projection, _view, _world * model)
        ifValid texture {
            log.trace(parent.type, ^{ mouseEvent.asString() + " -> " + texture.asString() })
            scenePoint : point(
                (texture.x * textureSize.w as f32) as i32
                textureSize.h - 1 - (texture.y * textureSize.h as f32) as i32)

            newMouseEvent : mouseEvent(
                eventType : mouseEvent.eventType
                point : scenePoint
                isCaptured : mouseEvent.isCaptured
                isLeftDown : mouseEvent.isLeftDown
            )

            newMouseEvent.fireChildren(children)
        } elseEmpty {
            log.trace(parent.type, ^{ mouseEvent.asString() + " -> does not map" })
        }
    }
) { 
    ifValid id {
        modelsById[id] = weak (this as #model)
    }

    _framebuffer = glGenFramebuffer(textureSize)
    _texture = glGenTexture(textureSize)
    _renderbuffer = glGenRenderbuffer(textureSize)

    glPushFramebuffer(_framebuffer)
    glBindTexture(glTexture.GL_TEXTURE_2D, _texture)
    glTexParameteri(glTexture.GL_TEXTURE_2D, glTextureAttribute.GL_TEXTURE_WRAP_S, glTextureValue.GL_CLAMP_TO_EDGE)
    glTexParameteri(glTexture.GL_TEXTURE_2D, glTextureAttribute.GL_TEXTURE_WRAP_T, glTextureValue.GL_CLAMP_TO_EDGE)
    glTexParameteri(glTexture.GL_TEXTURE_2D, glTextureAttribute.GL_TEXTURE_MIN_FILTER, glTextureValue.GL_LINEAR)
    glTexParameteri(glTexture.GL_TEXTURE_2D, glTextureAttribute.GL_TEXTURE_MAG_FILTER, glTextureValue.GL_LINEAR)
    glTexImage2D(glTexture.GL_TEXTURE_2D, 0, glTextureFormat.GL_RGBA, textureSize, glTextureType.GL_UNSIGNED_BYTE)
    glFramebufferTexture2D(glFramebufferAttachment.GL_COLOR_ATTACHMENT0, glFramebufferTexture.GL_TEXTURE_2D, _texture, 0)

    glBindRenderbuffer(_renderbuffer)
    glRenderbufferStorage(glRenderbufferFormat.GL_DEPTH_COMPONENT16, textureSize)
    glFramebufferRenderbuffer(glFramebufferAttachment.GL_DEPTH_ATTACHMENT, _renderbuffer)

    status : glCheckFramebufferStatus()
    if status != glFramebufferStatus.GL_FRAMEBUFFER_COMPLETE {
        halt("Framebuffer failed")       
    }
    glPopFramebuffer(_framebuffer)

    _innerScene.setSize(textureSize)
    rect : rect(0, 0, textureSize.w, textureSize.h)
    for i : 0 to children.count {
        child : children[i]
        child.setRect(rect)
    }
    this 
}