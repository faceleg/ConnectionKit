//
//  SVWebEditorTextRange.h
//  Sandvox
//
//  Created by Mike on 12/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  An DOMRange-inspired immutable object for holding a range in a manner that can outlive the DOM. The start & end objects should generally be either paragraphs, or title/text boxes. Indexes specify a number of *characters* offset from the object. This way they operate a little more like NSRange & NSAttributedString, ignoring any styling.


#import <WebKit/WebKit.h>


@interface SVWebEditorTextRange : NSObject <NSCopying>
{
  @private
    id          _containerObject;
    NSIndexPath *_startIndexPath;
    NSIndexPath *_endIndexPath;
}

- (id)initWithContainerObject:(id)container
               startIndexPath:(NSIndexPath *)startPath
                 endIndexPath:(NSIndexPath *)endPath;

+ (SVWebEditorTextRange *)rangeWithDOMRange:(DOMRange *)domRange
                            containerObject:(id)containerObject
                              containerNode:(DOMNode *)containerNode;

@property(nonatomic, retain, readonly) id containerObject;
@property(nonatomic, copy, readonly) NSIndexPath *startIndexPath;
@property(nonatomic, copy, readonly) NSIndexPath *endIndexPath;

- (void)populateDOMRange:(DOMRange *)range fromContainerNode:(DOMNode *)container;

@end
