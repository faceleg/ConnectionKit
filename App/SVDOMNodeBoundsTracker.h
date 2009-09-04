//
//  SVDOMNodeBoundingBoxTracker.h
//  Sandvox
//
//  Created by Mike on 03/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  This is a handy class. You supply it with a DOMNode and it will inform the delegate every time the node's boundingBox changes. It's generally intended as a building block for more sophisticated webview interaction.


#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@protocol SVDOMNodeBoundsTrackerDelegate;


@interface SVDOMNodeBoundsTracker : NSObject <DOMEventListener>
{
    DOMNode     *_node;
    NSArray     *_observedContainingViews;
    DOMDocument *_document;
    
    id <SVDOMNodeBoundsTrackerDelegate> _delegate;
}

// This automatically starts tracking too.
- (id)initWithDOMNode:(DOMNode *)node;

@property(nonatomic, retain, readonly) DOMNode *DOMNode;

// Start or stop tracking. Inapplicable requests will be ignored (e.g. stopping tracking twice)
- (void)startTracking;
- (void)stopTracking;

@property(nonatomic, assign) id <SVDOMNodeBoundsTrackerDelegate> delegate;

@end



@protocol SVDOMNodeBoundsTrackerDelegate
- (void)trackerDidDetectDOMNodeBoundsChange:(NSNotification *)notification;
@end