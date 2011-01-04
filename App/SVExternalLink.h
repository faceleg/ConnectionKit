//
//  SVExternalLink.h
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVSiteItem.h"


@interface SVExternalLink : SVSiteItem  

@property(nonatomic, retain) NSString *linkURLString;
- (void)setURL:(NSURL *)URL;  // wrapper around .linkURLString

@end



