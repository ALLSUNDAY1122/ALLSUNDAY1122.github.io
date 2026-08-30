# Haptics ownership

Session C owns haptic abstraction and iOS implementation. Gameplay/world code emits semantic events (`jump`, `dash`, `death`, `goal`, `purchase`, `unlock`) rather than invoking native APIs. Implementation is scheduled for C Next 2.
