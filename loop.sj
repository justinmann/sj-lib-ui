loopLastRect := rect()

mainLoop_lastTick := 0
mainLoop_frames := 0
mainLoop_showFPS := false
mainLoop_shouldContinue := true

mainLoop() {
    shouldAppContinue := true
    ticks := 0
    --c--
    ticks = SDL_GetTicks();
    --c--
    animator.nextFrame(ticks)

    if mainLoop_showFPS {
        mainLoop_frames++
        if mainLoop_lastTick + 1000 < ticks {
            fps : mainLoop_frames as f32 * 1000.0f / (ticks - mainLoop_lastTick) as f32
            debug.writeLine("FPS: " + fps.asString())
            mainLoop_lastTick = ticks
            mainLoop_frames = 0
        }
    }

    size : rootWindowRenderer.getSize()
    rootScene.setSize(size)
    rootScene.start()
    rect : rect(0, 0, size.w, size.h)
    if loopLastRect != rect {
        root.setRect(rect)
    }
    root.render(rootScene)
    rootScene.end()
    rootWindowRenderer.present()

    --c--
    SDL_Event e;
    while(SDL_PollEvent( &e ) != 0) {
    --c--
        mouse_eventType := empty'mouseEventType
        mouse_x := 0
        mouse_y := 0
        mouse_isLeftDown := false

        --c--
        switch (e.type) {
            case SDL_QUIT:
                shouldappcontinue = false;
                break;
            case SDL_MOUSEBUTTONDOWN:
                mouse_eventtype.isvalid = true;
                mouse_eventtype.value = g_mouseeventtype_down;
                mouse_x = e.button.x;
                mouse_y = e.button.y;
                mouse_isleftdown = e.button.state & SDL_BUTTON(SDL_BUTTON_LEFT);
                break;
            case SDL_MOUSEBUTTONUP:
                mouse_eventtype.isvalid = true;
                mouse_eventtype.value = g_mouseeventtype_up;
                mouse_x = e.button.x;
                mouse_y = e.button.y;
                mouse_isleftdown = e.button.state & SDL_BUTTON(SDL_BUTTON_LEFT);
                break;
            case SDL_MOUSEMOTION:
                mouse_eventtype.isvalid = true;
                mouse_eventtype.value = g_mouseeventtype_move;
                mouse_x = e.motion.x;
                mouse_y = e.motion.y;
                mouse_isleftdown = SDL_GetGlobalMouseState(0, 0) & SDL_BUTTON(SDL_BUTTON_LEFT);
                break;
        }
        --c--

        shouldContinue := true // TODO: should not need this
        ifValid mouse_eventType {
            ifValid m : mouse_captureElement {
                shouldContinue = m.fireMouseEvent(mouseEvent(
                    eventType : mouse_eventType
                    point : point(mouse_x, mouse_y)
                    isCaptured : true
                    isLeftDown : mouse_isLeftDown
                )) 
                void
            } elseEmpty {
                shouldContinue = root.fireMouseEvent(mouseEvent(
                    eventType : mouse_eventType
                    point : point(mouse_x, mouse_y)
                    isCaptured : false
                    isLeftDown : mouse_isLeftDown
                )) 
                void
            }
        }
    --c--
    }
    --c--

    mainLoop_shouldContinue = shouldAppContinue
    void
}

runLoop() {
    --c--
##ifdef EMSCRIPTEN
    emscripten_set_main_loop((em_callback_func)sjf_mainloop, 0, 0);
    exit(0);
##else
    while (g_mainloop_shouldcontinue) {
        #functionStack(mainLoop)();
    }
##endif 
    --c--
}