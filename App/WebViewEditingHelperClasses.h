//
//  WebViewEditingHelperClasses.h
//  Marvel
//
//  Created by Mike on 23/12/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TypewriterOn : NSObject
@end

@interface TypewriterOff : NSObject
@end

@interface EditableNodeFilter : NSObject <DOMNodeFilter>
+ (EditableNodeFilter *)sharedFilter;
@end

@interface KTEditableImageDOMFilter : NSObject <DOMNodeFilter>

+ (KTEditableImageDOMFilter *)sharedFilter;
- (short)acceptNode:(DOMNode *)node;

@end


@interface KTEditableEmbedMovieDOMFilter : NSObject <DOMNodeFilter>

+ (KTEditableEmbedMovieDOMFilter *)sharedFilter;
- (short)acceptNode:(DOMNode *)node;

@end

@interface KTEditableObjectMovieDOMFilter : NSObject <DOMNodeFilter>

+ (KTEditableObjectMovieDOMFilter *)sharedFilter;
- (short)acceptNode:(DOMNode *)node;

@end

@interface ScriptNodeFilter : NSObject <DOMNodeFilter>

+ (ScriptNodeFilter *)sharedFilter;
- (short)acceptNode:(DOMNode *)node;

@end

