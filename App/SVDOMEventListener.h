//
//  SVDOMEventListener.h
//  Sandvox
//
//  Created by Mike on 12/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Somewhat problematically, the DOM will retain any event listeners added to it. This can quite easily leave the listener as being retained only by the DOM, but when the DOM is torn down, it somehow releases the listener repeatedly, causing a crash.
//  The best solution I can come up with is to avoid the retain cycle between listener and DOM by creating a dumb SVDOMEventListener object. It will listen to events and forward them on to the real target, but not retain either object.


#import <WebKit/WebKit.h>


@interface SVDOMEventListener : NSObject <DOMEventListener>
{
  @private
    id <DOMEventListener>   _target;    // weak ref
}

@property(nonatomic, assign) id <DOMEventListener> eventsTarget;

@end
