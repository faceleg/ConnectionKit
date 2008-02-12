//
//  KTMediaURLProtocol.h
//  Marvel
//
//  Created by Terrence Talbot on 6/30/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTURLProtocol.h"

@class KTManagedObjectContext;
@interface KTMediaURLProtocol : KTURLProtocol { }

/*! returns media:/ URL for media object with uniqueID aMediaID and (optionally) anImageName */
+ (NSURL *)URLForDocument:(KTDocument *)aDocument 
				  mediaID:(NSString *)aMediaID
				imageName:(NSString *)anImageName;

@end
