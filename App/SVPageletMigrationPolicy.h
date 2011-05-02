//
//  SVPageletMigrationPolicy.h
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVPageletMigrationPolicy : NSEntityMigrationPolicy
@end


@interface SVMediaGraphicMigrationPolicy : SVPageletMigrationPolicy
@end


@interface SVIndexMigrationPolicy : SVPageletMigrationPolicy
@end
