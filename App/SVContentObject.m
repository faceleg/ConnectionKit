//
//  SVContentObject.m
//  Sandvox
//
//  Created by Mike on 29/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVDOMController.h"
#import "SVHTMLTemplateParser.h"
#import "SVBlogSummaryDOMController.h"


@implementation SVContentObject

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context; // default calls -HTMLString and writes that to the current context
{    
    SUBCLASSMUSTIMPLEMENT;
}

- (void)writeHTML; { [self writeHTML:[[SVHTMLTemplateParser currentTemplateParser] HTMLContext]]; }

#pragma mark Inspection

- (id)valueForUndefinedKey:(NSString *)key
{
    return NSNotApplicableMarker;
}

@end
