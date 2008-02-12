//
//  PrivateComponents.h
//  KTComponents
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
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

// Core Data-based objects

//  document storage
#import "KTDocumentInfo.h"

//  converts file to a new model
#import "KTDataMigrator.h"

// in-line elements
#import "KTPseudoElement.h"
#import "KTInlineImageElement.h"

// template parsing
#import "KTHTMLParser.h"

// foundation extensions
#import "NSMutableSet+KTExtensions.h"

// appkit extensions
#import "NSDocumentController+KTExtensions.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSToolbar+KTExtensions.h"
#import "NSView+KTExtensions.h"
#import "NSWindow+KTExtensions.h"

// core data extensions
#import "NSEntityDescription+KTExtensions.h"
#import "NSFetchRequest+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"
#import "NSPersistentStoreCoordinator+KTExtensions.h"

// appkit subclasses
#import "KTBorderlessWindow.h"
#import "KTOffScreenWebViewController.h"
#import "KTView.h"

// generic utilities, as class methods 
#import "KTUtilities.h"

// third party
#import "AQDataExtensions.h"
