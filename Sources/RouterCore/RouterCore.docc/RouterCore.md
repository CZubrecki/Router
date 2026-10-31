# ``RouterCore``

A type-safe, observable navigation model that runs anywhere, including headless on macOS.

## Overview

``Router`` holds the selected tab, a navigation stack per tab, and at most one sheet and one full-screen cover, each with its own stack.
Apps define four enums (tabs, destinations, sheets, covers) and drive navigation through a small set of verbs that take a ``Router/Context``.

Navigation is a value: read it as a ``Router/Snapshot``, restore it, render it as a route string, and observe every change as a ``Router/NavigationEvent``.
`RouterCore` imports only Foundation and Observation, so tests and command-line tools can drive an app's navigation without a simulator.
SwiftUI bindings live in `RouterUI`.

## Topics

### Defining routes

- ``RouterTab``
- ``RouterDestination``
- ``RouterSheet``
- ``RouterFullScreenCover``

### The router

- ``Router``
- ``Router/Context``
- ``Router/Modal``
- ``SheetPresentation``
- ``FullscreenCoverPresentation``

### State and events

- ``Router/Snapshot``
- ``Router/NavigationEvent``
- ``Router/Presentation``

### Routes and deep links

- ``URLRoutableTab``
- ``URLRoutableDestination``
- ``URLRoutableSheet``
- ``URLRoutableFullScreenCover``
- ``RouteFormat``
- ``DeepLinkError``
