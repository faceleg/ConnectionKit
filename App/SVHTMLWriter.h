//
//  SVTextDOMControllerHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Super simple KSHTMLWriter subclass that uses a delegate instead of that weird pseudo-delegate


#import "KSHTMLWriter.h"


@protocol SVHTMLWriterDelegate;
@interface SVHTMLWriter : KSHTMLWriter
{
  @private
    id <SVHTMLWriterDelegate>   _delegate;
}

@property(nonatomic, assign) id <SVHTMLWriterDelegate> delegate;

@end


@protocol SVHTMLWriterDelegate <NSObject>
- (BOOL)HTMLWriter:(KSHTMLWriter *)writer writeDOMElement:(DOMElement *)element;
@end