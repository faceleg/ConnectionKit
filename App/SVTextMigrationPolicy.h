//
//  SVTextMigrationPolicy.h
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVEntityMigrationPolicy.h"


@interface SVArticleMigrationPolicy : SVEntityMigrationPolicy

@end


@interface SVAuxiliaryPageletTextMigrationPolicy : SVArticleMigrationPolicy
@end


@interface SVTitleMigrationPolicy : SVEntityMigrationPolicy
@end


@interface SVPageTitleMigrationPolicy : SVTitleMigrationPolicy
@end



@interface SVFooterMigrationPolicy : SVEntityMigrationPolicy
@end
