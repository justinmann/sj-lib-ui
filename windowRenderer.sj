windowRenderer(
    --cvar--
    SDL_Window* win;
    SDL_Renderer* ren;
    --cvar--

    getSize()'size {
        w := 0
        h := 0
        --c--
        SDL_GetRendererOutputSize(_parent->ren, &w, &h);
        --c--
        size(w, h)
    }

    setSize(s : 'size) {
        --c--
        SDL_SetWindowSize(_parent->win, s->w, s->h);
        --c--
    }

    present()'void {
        --c--
        SDL_GL_SwapWindow((SDL_Window*)_parent->win);
        --c--
        void
    }
) {
    --c--
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        halt("SDL_Init Error: %s\n", SDL_GetError());
    }

##ifdef __APPLE__
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
##else
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
##endif
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    _this->win = SDL_CreateWindow("Hello World!", 100, 100, 640, 480, SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    if (_this->win == 0) {
        halt("SDL_CreateWindow Error: %s\n", SDL_GetError());
    }

    SDL_GL_CreateContext((SDL_Window*)_this->win);
##ifdef WIN32
    GLint GlewInitResult = glewInit();
    if (GLEW_OK != GlewInitResult) 
    {
        halt("ERROR: %s\n", glewGetErrorString(GlewInitResult));
    }
##endif

    _this->ren = SDL_CreateRenderer((SDL_Window*)_this->win, -1, SDL_RENDERER_ACCELERATED);
    if (_this->ren == 0) {
        halt("SDL_CreateRenderer Error: %s\n", SDL_GetError());
    }

    --c--
    glClearColor(color(0.0f, 0.0f, 0.0f, 0.0f))
    glBlendFunc(glBlendFuncType.GL_SRC_ALPHA, glBlendFuncType.GL_ONE_MINUS_SRC_ALPHA)
    glEnable(glFeature.GL_BLEND)
    this
} copy {
    --c--
    _this->ren = _from->ren;
    ptr_retain(_this->ren);
    _this->win = _from->win;
    ptr_retain(_this->win);
    --c--
} destroy {
    --c--
    if (ptr_release(_this->ren)) {
        SDL_DestroyRenderer(_this->ren);
    }
    if (ptr_release(_this->win)) {
        SDL_DestroyWindow(_this->win);
    }
    --c--
}

windowRender_disableVSync() {
    --c--
    SDL_GL_SetSwapInterval(0);
    --c--
}