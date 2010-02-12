//
//  SVWebEditorTextRange.h
//  Sandvox
//
//  Created by Mike on 12/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  An DOMRange-inspired immutable object for holding a range in a manner that can outlive the DOM. The start & end objects should generally be either paragraphs, or title/text boxes. Indexes specify a number of *characters* offset from the object. This way they operate a little more like NSRange & NSAttributedString, ignoring any styling.


#import <WebKit/WebKit.h>


@interface SVWebEditorTextRange : NSObject <NSCopying>
{
  @private
    id          _startObject;
    NSUInteger  _startIndex;
    id          _endObject;
    NSUInteger  _endIndex;
}

- (id)initWithStartObject:(id)startObject index:(NSUInteger)startIndex
                endObject:(id)endObject index:(NSUInteger)endIndex;

+ (SVWebEditorTextRange *)rangeWithDOMRange:(DOMRange *)domRange
                               startElement:(DOMElement *)startElement
                                     object:(id)startObject
                                 endElement:(DOMElement *)endElement
                                     object:(id)endObject;

@property(nonatomic, retain, readonly) id startObject;
@property(nonatomic, readonly) NSUInteger startIndex;
@property(nonatomic, retain, readonly) id endObject;
@property(nonatomic, readonly) NSUInteger endIndex;

- (void)populateDOMRange:(DOMRange *)range
        withStartElement:(DOMElement *)startElement
              endElement:(DOMElement *)endElement;

@end
