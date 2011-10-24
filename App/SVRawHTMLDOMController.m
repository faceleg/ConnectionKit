//
//  SVRawHTMLDOMController.m
//  Sandvox
//
//  Created by Mike on 14/05/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVRawHTMLDOMController.h"

#import "KTDocWindowController.h"
#import "KTHTMLEditorController.h"


@implementation SVRawHTMLDOMController

- (void)editRawHTMLInSelectedBlock:(id)sender;
{
    KTHTMLEditorController *controller = [[[[self webEditor] window] windowController] HTMLEditorController];
    SVRawHTMLGraphic *graphic = [self representedObject];
    
    SVTitleBox *titleBox = [graphic titleBox];
    [controller setTitle:[titleBox text]];
    
    [controller setHTMLSourceObject:graphic];	// so it can save things back.
    
    [controller showWindow:nil];
}

@end


#pragma mark -


@implementation SVRawHTMLGraphic (SVRawHTMLDOMController)

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID ancestorNode:(DOMNode *)document;
{
    SVDOMController *result = [[SVRawHTMLDOMController alloc] initWithIdName:elementID ancestorNode:document];
    [result setRepresentedObject:self];
    return result;
}

@end
