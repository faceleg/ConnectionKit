//
//  SVContentObject.h
//  Sandvox
//
//  Created by Mike on 29/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.

//  A typical page is made up of lots of little scraps of content: paragraphs, pagelets, plug-ins etc. Each of these should be a descendant of SVContentObject as it provides the basic facilities they need:
//
//      -   Generate an HTML string representation of themself. This could be from just the receiver, or by recursively piecing together the HTML of various sub-content.
//  
//      -   When editing, each content object must be uniquely identifiable in the WebView so that appropriate controllers can be hooked up. First, the content object generating an HTML element with an id specified. Then, each content object is asked to locate itself in the DOM by the controller.


#import "KSExtensibleManagedObject.h"
#import <WebKit/WebKit.h>


@interface SVContentObject : KSExtensibleManagedObject

#pragma mark Basic HTML

//  Raises an exception, so you must override in your subclass
- (NSString *)HTMLString;


#pragma mark Editing Support

//  Uses the receiver's -editingElementID to locate the matching DOM element. Returns nil if nothing suitable is found. The default implementation works fine, but it could be useful for subclasses to check the return value to make sure it matches expectations, and return nil if it doesn't.
- (DOMHTMLElement *)elementForEditingInDOMDocument:(DOMDocument *)document;

// Default is NO. Override if you want it to be published.
- (BOOL)shouldPublishEditingElementID;

// The returned ID should be suitable for using as a DOMElement's ID attribute. It should be unique for the page being generated. The default implementation is based upon the receiver's location in memory, as it is assumed that the object will be retained for the duration of the editing cycle. Subclasses can override to specify a different ID format, perhaps because the object will already generate a unique ID as part of its HTML.
- (NSString *)editingElementID;

//  A subclass of SVDOMController that the WebEditor will create and maintain in order to edit the object. The default is a vanila SVDOMController.
//  I appreciate this slightly crosses the MVC divide, but the important thing is that the receiver never knows about any _specific_ controller, just the class involved.
- (Class)DOMControllerClass;

@end
