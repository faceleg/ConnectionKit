//
//  KTDocumentInfo.h
//  KTComponents
//
//  Copyright (c) 2005, Karelia Software. All rights reserved.
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

#import "KTManagedObject.h"


typedef enum {
	KTCopyMediaAutomatic = 0,
	KTCopyMediaAll,
	KTCopyMediaNone
} KTCopyMediaType;



@class KTPage,KTHostProperties;


@interface KTDocumentInfo : KTManagedObject 
{
}

- (NSString *)siteID;
- (KTPage *)root;
- (KTHostProperties *)hostProperties;

- (KTCopyMediaType)copyMediaOriginals;
- (void)setCopyMediaOriginals:(KTCopyMediaType)copy;

- (NSSet *)requiredBundlesIdentifiers;
- (void)setRequiredBundlesIdentifiers:(NSSet *)identifiers;

- (NSDictionary *)metadata;
- (void)setMetadata:(NSDictionary *)metadata;

- (NSString *)appNameVersion;

// Site menu
- (NSArray *)pagesInSiteMenu;
- (void)invalidatePagesInSiteMenuCache;

// Google sitemap
- (NSString *)googleSiteMapXMLString;

@end
