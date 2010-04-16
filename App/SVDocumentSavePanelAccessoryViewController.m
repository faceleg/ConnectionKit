//
//  SVDocumentSavePanelAccessoryViewController.m
//  Sandvox
//
//  Created by Mike on 16/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDocumentSavePanelAccessoryViewController.h"


@implementation SVDocumentSavePanelAccessoryViewController

- (BOOL)copyMoviesIntoDocument;
{
    [self view];    // Make sure it's loaded
    
    BOOL result = ([oCopyMoviesCheckbox state] == NSOnState);
    return result;
}

@end
