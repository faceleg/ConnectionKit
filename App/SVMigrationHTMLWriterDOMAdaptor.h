//
//  SVMigrationHTMLWriterDOMAdaptor.h
//  Sandvox
//
//  Created by Mike on 24/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVParagraphedHTMLWriterDOMAdaptor.h"


@class SVRichTextDOMController;


@interface SVMigrationHTMLWriterDOMAdaptor : SVParagraphedHTMLWriterDOMAdaptor
{
  @private
    SVRichTextDOMController *_articleController;
}

@property(nonatomic, assign) SVRichTextDOMController *textDOMController;

@end
