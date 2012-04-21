Proton is a utility framework for Cocoa and Cocoa Touch that provides tools useful for building a powerful model layer.

# Features

 - A simple and extensible system for bindings, suitable for use on iOS and for replacing Cocoa Bindings on OS X
 - Components to make Core Data easier to use, including:
    - `PROCoreDataManager`, to manage all the resources associated with a single database
    - Support for copying managed objects between contexts
    - Support for encoding and decoding managed objects to and from property lists
    - Convenience methods on `NSManagedObject` and `NSManagedObjectContext` so callers have to write less code
 - A class for key-value observing that makes it easier to manage the observation of many different objects or key paths
 - A couple macros to check key paths at compile time (i.e., fail to build when an invalid key path is used)
 - Higher-order functions (map, filter, fold) for _all_ built-in collection classes
 - Extensions to `NSUndoManager` to support blocks and make it simpler to manage undo groupings
 - `PROFuture`, an extremely fast and simple implementation of block-based futures

All of the above features are unit tested, to validate the typical use cases and detect any future breakage.

Proton has been built with the [Model-View-ViewModel](http://en.wikipedia.org/wiki/Model_View_ViewModel) architectural pattern in mind. The `PROViewModel` abstract class can serve as a base for any application-specific view model layer.

# Dependencies

All dependencies can be retrieved by running `git submodule update --init --recursive` from the top level of the repository.

 - Xcode projects in the repository are configured using prebuilt [xcconfigs](http://github.com/jspahrsummers/xcconfigs)
 - The unit tests for Proton are written using [Specta](http://github.com/bitswift/specta) and [Expecta](http://github.com/bitswift/expecta)
 - Logging is implemented using the [CocoaLumberjack](http://github.com/bitswift/CocoaLumberjack) logging framework
 - Parts of [libextobjc](http://github.com/jspahrsummers/libextobjc) and [SafeDispatch](http://github.com/jspahrsummers/SafeDispatch) are used in Proton (but are already present in the repository)

# License

Proton is released under a modified version of the 3-clause BSD license. See the LICENSE file for more information.
