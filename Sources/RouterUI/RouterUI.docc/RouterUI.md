# ``RouterUI``

SwiftUI integration for `RouterCore`'s `Router`.

## Overview

`RouterUI` re-exports `RouterCore` and adds what views need: navigation-stack bindings for tabs, sheets, and covers, a one-line deep-link modifier, and ``TabPresentable`` for tab-bar titles and images.
Keep tab enums in a UI-free package and add ``TabPresentable`` conformance in the UI layer.

## Topics

### Tab bar

- ``TabPresentable``
- ``TabImage``

### Bindings and modifiers

- ``Router/pathBinding(for:)``
- ``Router/sheetPathBinding()``
- ``Router/fullscreenCoverPathBinding()``
- ``SwiftUICore/View/onOpenURL(with:treatHostAsPath:)``
