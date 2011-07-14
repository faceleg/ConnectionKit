//
//  SVDOMController.h
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  
//  Sandvox's general class for other controllers to subclass.
//  Supports NSWidthBinding.
//


#import "WebEditingKit.h"

#import "SVContentObject.h"
#import "SVHTMLContext.h"

#import "KSDependenciesTracker.h"


@class SVWebEditorHTMLContext, KSObjectKeyPathPair, SVWebEditorViewController, SVGraphic, SVResizableDOMController;
@protocol SVDOMControllerRepresentedObject;


@interface SVDOMController : WEKWebEditorItem <KSDependenciesTrackerDelegate>
{
  @private
    // Loading
    BOOL        _shouldPublishElementID;
    
    // Updating
    NSMutableSet            *_updateSelectors;
    NSNumber                *_width;
    KSDependenciesTracker   *_dependenciesTracker;
    SVWebEditorHTMLContext  *_context;
    
    // MOC
    NSManagedObjectContext  *_moc;
    
    // Moving
    BOOL    _moving;
    CGPoint _relativePosition;
    
    // Dragging
    NSArray *_dragTypes;
}

#pragma mark Hierarchy
- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;


#pragma mark DOM Element Loading

@property(nonatomic) BOOL shouldIncludeElementIdNameWhenPublishing;

@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;


#pragma mark Updating
- (BOOL)canUpdate;  // default is [self respondsToSelector:@selector(update)]
- (void)didUpdateWithSelector:(SEL)selector;    // you MUST call this after updating


#pragma mark Marking for Update

// If the receiver supports updating itself (-canUpdate), schedules an update with -setNeedsUpdateWithSelector:
// Otherwise, proceeds up the hierarchy looking for a controller that does support updating
- (void)setNeedsUpdate;

// Direct action to schedule a selector on next runloop pass
- (void)setNeedsUpdateWithSelector:(SEL)selector;

@property(nonatomic, readonly) BOOL needsUpdate;    // have any updates been registered?
- (BOOL)needsToUpdateWithSelector:(SEL)selector;    // has a specific selector been registered?

- (void)updateIfNeeded; // recurses down the tree


#pragma mark Size Binding
// Width value is stored in an ivar, NOT read from the DOM. You can bind it with NSWidthBinding
@property(nonatomic, copy) NSNumber *width;


#pragma mark Generic Dependencies
@property(nonatomic, copy, readonly) NSSet *dependencies;
- (void)addDependency:(KSObjectKeyPathPair *)pair;
- (void)removeAllDependencies;
- (void)startObservingDependencies; // recursive
- (void)stopObservingDependencies;  // guaranteed to be called by -dealloc if needed


#pragma mark Content
// Automatically set from represented object is possible
// In general this is an ugly workaround for the problem of DOM controllers outliving their represented object's MOC. I think ideally the DOM Controller ought to observe an NSObjectController (or subclass) such that the MOC is handled there
@property(nonatomic, retain) NSManagedObjectContext *managedObjectContext;


#pragma mark Editing
- (void)delete;
- (BOOL)shouldHighlightWhileEditing;


#pragma mark Resizing
- (NSSize)minSize;
- (CGFloat)maxWidth;
- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
- (unsigned int)resizingMaskForDOMElement:(DOMElement *)element;    // support


#pragma mark Moving
- (void)moveToRelativePosition:(CGPoint)position;
- (void)moveToPosition:(CGPoint)position;   // takes existing relative position into account
- (void)removeRelativePosition:(BOOL)animated;
- (BOOL)hasRelativePosition;
- (CGPoint)positionIgnoringRelativePosition;
- (NSRect)rectIgnoringRelativePosition;
- (NSArray *)relativePositionDOMElements;


#pragma mark Dragging
- (void)registerForDraggedTypes:(NSArray *)newTypes;
- (void)unregisterDraggedTypes;
- (NSArray *)registeredDraggedTypes;


@end


#pragma mark -


@protocol SVDOMControllerRepresentedObject <NSObject>

//  A subclass of SVDOMController that the WebEditor will create and maintain in order to edit the object. The default is a vanilla SVDOMController.
//  I appreciate this slightly crosses the MVC divide, but the important thing is that the receiver never knows about any _specific_ controller, just the class involved.
- (SVDOMController *)newDOMController;

@end


// And provide a base implementation of the protocol:
@interface SVContentObject (SVDOMController) <SVDOMControllerRepresentedObject>
@end


#pragma mark -


/*  We want all Web Editor items to be able to handle updating in some form, just not necessarily the full complexity of it.
*/

@interface WEKWebEditorItem (SVDOMController)

#pragma mark DOM
- (void)loadHTMLElementFromDocument:(DOMDocument *)document;    // does nothing


#pragma mark Updating
- (SVWebEditorViewController *)webEditorViewController;
- (void)setNeedsUpdate; // pass up to parent
- (void)updateIfNeeded; // recurses down the tree
- (SVWebEditorHTMLContext *)HTMLContext;


#pragma mark Dependencies
- (BOOL)isObservingDependencies;
- (void)startObservingDependencies; // recursive
- (void)stopObservingDependencies;  // recursive


#pragma mark Moving in Article

// Default implementation doesn't know how to handle the move, so passes on, asking parent to move itself. Generally item should be a child
- (void)moveItemUp:(WEKWebEditorItem *)item;
- (void)moveItemDown:(WEKWebEditorItem *)item;

// Ask parent to move receiver
- (void)moveUp;
- (void)moveDown;


#pragma mark Drag & Drop
- (NSArray *)registeredDraggedTypes;


@end


#pragma mark -


@interface WEKDOMController (SVDOMController)

- (DOMNode *)previousDOMNode;
- (DOMNode *)nextDOMNode;


#pragma mark Moving
- (void)exchangeWithPreviousDOMNode;
- (void)exchangeWithNextDOMNode;


@end

