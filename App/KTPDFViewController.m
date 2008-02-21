//
//  KTPDFViewController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "KTPDFViewController.h"

#import "NSObject+Karelia.h"


@implementation KTPDFViewController

/*! returns shared instance that owns nib */
+ (id)sharedController
{
	[self subclassResponsibility:_cmd];
    return nil;
}

/*! override to load oTextView with relevant content */
- (void)windowDidLoad
{
    
}

- (id)init
{
    if ( ![super initWithWindowNibName:@"PDFWindow"] )
    {
        return nil;
    }
    
    return self;
}

@end
