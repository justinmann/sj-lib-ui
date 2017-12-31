enum imageStretch (
    fill
    center
    aspectRatio
)

imageElement #element (
    image := 'image
    margin := margin()
    stretch := imageStretch.fill
    _rect := rect()
    _imageRenderer := empty'imageRenderer

    getSize(maxSize : 'size) {
        size(maxSize.w, maxSize.h)
    }

    getRect()'rect { _rect }

    setRect(rect_ : 'rect)'void {
        if _rect != rect_ {
            _rect = rect_
            _imageRenderer = empty'imageRenderer
        }
        void
    }

    render(scene : 'scene2d)'void {
        if isEmpty(_imageRenderer) {
            r := _rect.subtractMargin(margin)
            switch stretch {
                imageStretch.fill { }
                imageStretch.center { 
                    s : size(r.w, r.h)
                    finalSize : s.min(image.texture.size)
                    r = rect(
                        (r.w - finalSize.w) / 2
                        (r.h - finalSize.h) / 2
                        finalSize.w
                        finalSize.h
                    )
                    void
                }
                imageStretch.aspectRatio { 
                    imageAspectRatio : image.texture.size.w as f32 / image.texture.size.h as f32
                    rectAspectRatio  : r.w as f32 / r.h as f32
                    finalSize : if imageAspectRatio > rectAspectRatio {
                        size(r.w, (r.h as f32 / imageAspectRatio) as i32)
                    } else {
                        size((r.w as f32 * imageAspectRatio) as i32, r.h)
                    }
                    r = rect(
                        (r.w - finalSize.w) / 2
                        (r.h - finalSize.h) / 2
                        finalSize.w
                        finalSize.h
                    )
                    void
                }
            }

            _imageRenderer = valid(imageRenderer(
                image : image
                rect : r
            ))

            void
        }

        _imageRenderer?.render(scene)
    }

    fireMouseEvent(mouseEvent : 'mouseEvent) {
        true
    }
) { this }