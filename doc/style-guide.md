# Coding standards

This applies to new code, and as you're working with code in TouchDB. 
For now, existing TouchDB code is given a pass.

## Before starting

Read Apple's [Coding Guidelines for Cocoa][1]. The following is mostly 
about style; Apple's guidelines cover the essentials of naming.

[1]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html#//apple_ref/doc/uid/10000146-SW1

## Citations

- The [Google guidelines](http://google-styleguide.googlecode.com/svn/trunk/objcguide.xml).
- [NYT Guidelines](https://github.com/NYTimes/objective-c-style-guide)

## Automating

Code style for CDTDatastore is defined with a clang format file (.clang-format) in the 
root of the project. All code should be formatted using the clang-format tool. 

### Installing clang-format into Xcode

Clang-format can be installed into Xcode using the 
[ClangFormat-Xcode](https://github.com/travisjeffery/ClangFormat-Xcode) plug-in. 
The easiest way to do this is via [Alcatraz](https://github.com/mneorr/Alcatraz). 
You can also install the plugin from source using the instractions at 
[ClangFormat-Xcode](https://github.com/travisjeffery/ClangFormat-Xcode).

#### Setting up Xcode

You can set up `ClangFormat-Xcode` to format the whole file on every save. Unfortunately,
many of the files in the codebase are not yet formatted, so we suggest *not* setting this
up as if you do you'll be picking apart hundreds of lines of whitespace changes from
your actual changes to separate their commits. Instead, run the formatter over just
the code you change.

You can set up a hotkey for formatting selected text as follows:

1. Open _System Preferences_ > _Keyboard_ > _Shortcuts_ > _App Shortcuts_. Click `+`.
1. Set the application to be Xcode.
1. Set the menu title to "Format Selected Text".
1. Set your shortcut to `ctrl-i`.

## Mechanics

Your editor can be set up to enforce some of these.

### Spaces

4 spaces. No tabs. Set up your editor appropriately.

### Line length

100 characters. Use  _Preferences > Text Editing > Page guide at column: 100_ in Xcode.

Code review in GitHub is easier if one doesn't need to scroll horizontally.

### Blank Lines

- Blank lines should both precede and follow `@` entities like `@interface`,
  `@implementation`, `@end`.
- Group code into "paragraphs" within methods using a single blank line.
- One blank line between methods.
- Group imports with blank lines.

## Commenting

Commenting can be useful. Obviously it's more important to have
readable code; comments are for *why* not *how*.

- For comments in methods, use `//` comments.
- For doc comments, use appledoc `/** .... */`. If there is more than 
  one line to the comment, wrap the first line too.
- To comment out swathes of code, use `//` comments. Preferably at the 
  start of lines to match Xcode's behaviour.

## Error handling

_From the NYT guidelines._

When methods return an error parameter by reference, switch on the returned value, 
not the error variable.

**For example:**
```objc
NSError *error;
if (![self trySomethingWithError:&error]) {
    // Handle Error
}
```

**Not:**
```objc
NSError *error;
[self trySomethingWithError:&error];
if (error) {
    // Handle Error
}
```

Some of Apple’s APIs write garbage values to the error parameter (if non-NULL) 
in successful cases, so switching on the error can cause false negatives (and 
subsequently crash).

## Style

### Dot-notation

Any and all property accesses. Nowhere else.

### Conditionals and Loops

Spaces between the keyword and the braces; braces on the same line.

```objc
if (something) {
    // blah...
} else if (somethingElse) {
    // blah...
} else {
    // blah...
}
```

- Put common cases first.
- Prefer positive conditions (`if (something) {...} else {...}` over `if (!something) {...} else {...}`).
  It's easy to miss a `!` when reading a complex condition. Unless the negated condition is 
  much more likely to happen.

### Methods

#### Declarations

A space after the `-` or `+`. A space after class names when typing parameters. The brace 
on a new line.

```objc
- (NSString *)produceRandomStringWithLength:(NSInteger)length
{
    ...
}
```

#### Invocation

Similar rules apply for spacing. When wrapping  Cocoa messages, align by colon.

```objc
[myObject doFooWith:arg1 name:arg2 error:arg3];
[myObject doFooWith:arg1
               name:arg2
              error:arg3];
```

If wrapping, wrap *all* keywords onto a new line.

### Blocks

Always start a new line for a block, and indent four spaces from the left margin.

```objc
// Put the block's code on a new line, indented four spaces, with the
// closing brace aligned with the first character of the line on which
// block was declared.
[operation setCompletionBlock:^{
    [self.delegate newDataAvailable];
}];

// Using a block with a C API follows the same alignment and spacing
// rules as with Objective-C.
dispatch_async(_fileIOQueue, ^{
    NSString* path = [self sessionFilePath];
    if (path) {
      // ...
    }
});
```

### Container literals

Always prefer literals to methods. That is, for example, prefer `@{ var1, var2 }` over `[NSArray arrayWithObjects:var1, var2, nil]`.

When wrapping literals, prefer 4-space indents:

```objc
NSArray* array = @[
    @"This",
    @"is",
    @"an",
    @"array"
];
```

But it's okay to use Xcode's odd default:

```objc
NSDictionary* discouraged = @{ AKey : @"a",
                               BLongerKey : @"b" };
```

### Enums and Bitmasks

Remember Apple now has macros to help with this:

```
# Enums:
typedef NS_ENUM(NSInteger, NYTAdRequestState) {
    NYTAdRequestStateInactive,
    NYTAdRequestStateLoading
};

# Bitmasks:
typedef NS_OPTIONS(NSUInteger, NYTAdCategory) {
    NYTAdCategoryAutos      = 1 << 0,
    NYTAdCategoryJobs       = 1 << 1,
    NYTAdCategoryRealState  = 1 << 2,
    NYTAdCategoryTechnology = 1 << 3
};
```

4-spaces, as usual.

### Properties

Always prefer properties to instance variables.

Always access properties with dot-notation. Apart from in initialisers, and obviously
their own getter and setter methods.

Google's doc reminds us, "Instance subclasses may be in an inconsistent state 
during init and dealloc method execution, so code in those methods should avoid 
invoking accessors."

For more information on using Accessor Methods in Initializer Methods and dealloc, see [here](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmPractical.html#//apple_ref/doc/uid/TP40004447-SW6).

