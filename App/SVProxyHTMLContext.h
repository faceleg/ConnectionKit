//
//  SVProxyHTMLContext.h
//  Sandvox
//
//  Created by Mike on 21/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Like a regular HTML Context, but methods which do not directly write a string (-addMedia: etc.) get forwarded onto another context

#import "SVHTMLContext.h"


@interface SVProxyHTMLContext : SVHTMLContext
{
  @private
    SVHTMLContext   *_target;
}

- (id)initWithOutputWriter:(id <KSWriter>)output target:(SVHTMLContext *)targetContext;

@end
