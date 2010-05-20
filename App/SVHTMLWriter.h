//
//  SVTextDOMControllerHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Super simple KSHTMLWriter subclass that uses a delegate instead of that weird pseudo-delegate


#import "KSHTMLWriter+DOM.h"


@class SVHTMLBuffer;


@protocol SVHTMLWriterDelegate;
@interface SVHTMLWriter : KSHTMLWriter
{
  @private
    SVHTMLBuffer    *_buffer;
    BOOL            _flushOnNextWrite;
    
    id <SVHTMLWriterDelegate>   _delegate;
}

#pragma mark Elements/Comments
//  For when you have just closed an element and want to end up with this:
//  </div> <!-- comment -->
- (void)writeEndTagWithComment:(NSString *)comment;


#pragma mark Buffering
- (void)beginBuffering; // can be called multiple times to set up a stack of buffers
- (void)discardBuffer;  // only discards the most recent buffer. If there's a lower one in the stack, that is restored
- (void)flush;
- (void)flushOnNextWrite;


#pragma mark Delegate
@property(nonatomic, assign) id <SVHTMLWriterDelegate> delegate;


@end


#pragma mark -


@protocol SVHTMLWriterDelegate <NSObject>
- (BOOL)HTMLWriter:(KSHTMLWriter *)writer writeDOMElement:(DOMElement *)element;
@end