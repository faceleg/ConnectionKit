//
//  Debug.h
//  KTComponents
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "assertions.h"
// convenience; make assertions avaialble from debug.h

// usage is LOG((blah)); see, e.g., http://cocoa.mamasam.com/COCOADEV/2002/10/2/48288.php
// NB: the double parens are necessary to deal with NSLog varargs
// NSLogs used via these macros will *not* appear in a Release build

#ifndef LOG(x)
    #ifdef DEBUG 
        #define LOG(x) NSLog x 
		#define DJW(x) if ([NSUserName() isEqualToString:@"dwood"]) NSLog x 
		#define TJT(x) if ([NSUserName() isEqualToString:@"ttalbot"]) NSLog x 
		#define OFF(x)  
        #define DEBUG_ONLY(x) x 
    #else 
		#define LOG(x) 
		#define DJW(x) 
		#define TJT(x) 
		#define OFF(x) 
        #define DEBUG_ONLY(x) 
    #endif 
#endif

#ifndef LOGMETHOD
	#ifdef DEBUG
		#define LOGMETHOD NSLog(@"%@ %@", [self className], NSStringFromSelector(_cmd))
	#else
		#define LOGMETHOD
	#endif
#endif

#ifndef ISDEPRECATEDAPI
	#define ISDEPRECATEDAPI NSLog(@"%@, %@ is deprecated API -- DO NOT USE", [self className], NSStringFromSelector(_cmd))
#endif

#ifndef USESDEPRECATEDAPI
	#define USESDEPRECATEDAPI NSLog(@"%@, %@ uses deprecated API -- PLEASE REWRITE", [self className], NSStringFromSelector(_cmd))
#endif

#ifndef DEPRECATEDMETHOD
    #define DEPRECATEDMETHOD NSLog(@"%@, %@ has been deprecated", [self className], NSStringFromSelector(_cmd))
#endif

#ifndef NOTYETIMPLEMENTED
    #define NOTYETIMPLEMENTED NSLog(@"%@, %@ has not yet been implemented", [self className], NSStringFromSelector(_cmd))
#endif

#ifndef SUBCLASSMUSTIMPLEMENT
	#define SUBCLASSMUSTIMPLEMENT NSLog(@"%@, a subclass of %@, must implement %@", [self className], [super className], NSStringFromSelector(_cmd))
#endif

#ifndef RAISE_EXCEPTION
    #define RAISE_EXCEPTION(a, b, c) [[NSException exceptionWithName:(NSString *)a reason:(NSString *)b userInfo:(NSDictionary *)c] raise]
#endif

#ifdef DEBUG
    #ifndef RAISE_DEBUG_EXCEPTION
        #define RAISE_DEBUG_EXCEPTION(a, b, c) [[NSException exceptionWithName:(NSString *)a reason:(NSString *)b userInfo:(NSDictionary *)c] raise]
    #endif
#else
    #ifndef RAISE_DEBUG_EXCEPTION
        #define RAISE_DEBUG_EXCEPTION(a, b, c)
    #endif
#endif



