//
//  SVPageBodyTextDOMController.m
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageBodyTextDOMController.h"

#import "SVGraphicFactoryManager.h"
#import "SVHTMLContext.h"
#import "KTPage.h"
#import "SVPlugIn.h"


@implementation SVPageBodyTextDOMController

#pragma mark Properties

- (BOOL)allowsBlockGraphics; { return YES; }





- (IBAction)insertPagelet:(id)sender;
{
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    
    SVGraphic *graphic = [SVGraphicFactoryManager graphicWithActionSender:sender
                                           insertIntoManagedObjectContext:context];
    
    [self addGraphic:graphic placeInline:NO];
    [graphic awakeFromInsertIntoPage:[[self HTMLContext] currentPage]];
}

@end


@implementation SVPageBody (SVPageBodyTextDOMController)
- (Class)DOMControllerClass { return [SVPageBodyTextDOMController class]; }
@end