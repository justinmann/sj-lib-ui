rect(
    x : 0
    y : 0
    w : 0
    h : 0

    subtractMargin(margin : 'margin) {
        rect(x + margin.l, y + margin.t, w - margin.l - margin.r, h - margin.t - margin.b)
    }

    containsPoint(point : 'point) {
        x <= point.x && y <= point.y && point.x < x + w && point.y < y + h
    }
    
    isEqual(rect: 'rect) {
        x == rect.x && y == rect.y && w == rect.w && h == rect.h
    }

    asString() {
        "x: " + x.asString() + " y: " + y.asString() + " w: " + w.asString() + " h: " + h.asString()
    }
) { this }