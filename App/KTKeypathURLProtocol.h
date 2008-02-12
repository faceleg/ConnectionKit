//
//  KTKeypathURLProtocol.h
//  Marvel
//
//  Created by Terrence Talbot on 5/9/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTURLProtocol.h"

@interface KTKeypathURLProtocol : KTURLProtocol { }

+ (NSURL *)URLForDocument:(KTDocument *)aDocument keyPath:(NSString *)aKeyPath;

@end
