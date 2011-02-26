//
//  SVMigrationHTMLWriterDOMAdaptor.h
//  Sandvox
//
//  Created by Mike on 24/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVParagraphedHTMLWriterDOMAdaptor.h"


@class SVArticleDOMController;


@interface SVMigrationHTMLWriterDOMAdaptor : SVParagraphedHTMLWriterDOMAdaptor
{
  @private
    SVArticleDOMController  *_articleController;
}

@property(nonatomic, assign) SVArticleDOMController *articleDOMController;

@end
