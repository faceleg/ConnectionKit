//
//  SVFooterDOMController.m
//  Sandvox
//
//  Created by Mike on 01/03/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVFooterDOMController.h"

#import "KTMaster.h"
#import "SVMigrationHTMLWriterDOMAdaptor.h"


@implementation SVFooterDOMController

- (id)newHTMLWritingDOMAdaptorWithOutputStringWriter:(KSStringWriter *)stringWriter;
{
    KTMaster *master = [[self representedObject] valueForKey:@"master"];
    
    if ([[[master extensibleProperties] valueForKey:@"migrateRawHTMLOnNextEdit"] boolValue])
    {
        SVMigrationHTMLWriterDOMAdaptor *result = [[SVMigrationHTMLWriterDOMAdaptor alloc] initWithOutputStringWriter:stringWriter];
        
        [result setTextDOMController:self];
        
        // Stop this happening again
        [master removeExtensiblePropertyForKey:@"migrateRawHTMLOnNextEdit"];
        
        return result;
    }
    else
    {
        return [super newHTMLWritingDOMAdaptorWithOutputStringWriter:stringWriter];
    }
}

@end



#pragma mark -


@implementation SVFooter

- (SVTextDOMController *)newTextDOMController;
{
    SVTextDOMController *result = [[SVFooterDOMController alloc] initWithRepresentedObject:self];
    [result setRichText:YES];
    [result setFieldEditor:YES];
    [(id)result setImportsGraphics:YES];
    return result;
}

@end
