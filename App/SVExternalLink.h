//
//  SVExternalLink.h
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVSiteItem.h"


@interface SVExternalLink : SVSiteItem  
{
	NSString *_windowTitle;
	NSString *_metaDescription;
}


@property(nonatomic, retain) NSNumber *openInNewWindow;

@property(nonatomic, retain) NSString *linkURLString;
@property(nonatomic, copy) NSURL *URL;  // wrapper around .linkURLString

@end



