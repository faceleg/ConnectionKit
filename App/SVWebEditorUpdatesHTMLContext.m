//
//  SVWebEditorUpdatesHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorUpdatesHTMLContext.h"


@implementation SVWebEditorUpdatesHTMLContext

- (id)initWithDOMDocument:(DOMDocument *)document
             outputWriter:(id <KSWriter>)output
       inheritFromContext:(SVHTMLContext *)context;
{
    if (self = [self initWithOutputWriter:output inheritFromContext:context])
    {
        _document = [document retain];
    }
    
    return self;
}

- (void)close
{
    [super close];
    [_document release]; _document = nil;
}

- (NSURL *)addResourceAtURL:(NSURL *)fileURL destination:(NSString *)uploadPath options:(NSUInteger)options;
{
    if (_document && [uploadPath isEqualToString:SVDestinationMainCSS])
    {
        // Add directly into the DOM
        DOMElement *link = [_document createElement:@"link"];
        [link setAttribute:@"rel" value:@"stylesheet"];
        [link setAttribute:@"type" value:@"text/css"];
        [link setAttribute:@"href" value:[fileURL absoluteString]];
        
        [[[_document getElementsByTagName:@"HEAD"] item:0] appendChild:link];
        
        return fileURL;
    }
    else
    {
        return [super addResourceAtURL:fileURL destination:uploadPath options:options];
    }
}

@end
