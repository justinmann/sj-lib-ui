renderbuffer(
    size : size()
    id : 0u
) { 
    this 
} copy {
    --c--
    _this->id = _from->id;
    glid_retain(_this->id);
    --c--
} destroy {
    --c--
    if (glid_release(_this->id)) {
        glDeleteRenderbuffers(1, &_this->id);
    }
    --c--
}