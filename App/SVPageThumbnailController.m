//
//  SVPageThumbnailController.m
//  Sandvox
//
//  Created by Mike on 11/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageThumbnailController.h"

#import "SVMediaRecord.h"

#import "KSInspectorViewController.h"


@implementation SVPageThumbnailController

- (BOOL)setFileWithURL:(NSURL *)URL;
{
    NSManagedObjectContext *context = [[oInspectorViewController representedObject] managedObjectContext];
    
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:URL
                                            entityName:@"Thumbnail"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    [[oInspectorViewController inspectedObjectsController] replaceMedia:media
                                                             forKeyPath:@"selection.customThumbnail"];
    
    return YES;
}

@end
