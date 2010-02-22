//
//  KTStoredDictionary+HostProperties.h
//  Sandvox
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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

#import "KSExtensibleManagedObject.h"


@class SVDirectoryPublishingRecord;


@interface KTHostProperties : KSExtensibleManagedObject

- (BOOL)remoteSiteURLIsValid;
- (NSString *)globalBaseURLUsingHome:(BOOL)inHome allowNull:(BOOL)allowNull;
- (NSString *)globalSiteURL;
- (NSString *)localHostNameOrAddress;
- (NSString *)localPublishingRoot;
- (NSString *)localURL;
- (NSString *)remotePublishingRoot;
- (NSString *)remoteSiteURL;
- (NSString *)uploadURL;

// Sane API starts here
- (NSURL *)siteURL;
- (NSString *)documentRoot;
- (NSString *)subfolder;

- (NSURL *)resourcesDirectoryURL;
- (NSURL *)URLForResourceFile:(NSString *)filename;

- (NSString *)hostPropertiesReport;


#pragma mark Publishing Records
@property(nonatomic, retain) SVDirectoryPublishingRecord *rootPublishingRecord;


@end
