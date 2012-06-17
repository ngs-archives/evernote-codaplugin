//
//  EvernoteSession+coda.m
//  Evernote
//
//  Created by Atsushi Nagase on 6/17/12.
//  Copyright (c) 2012 LittleApps Inc. All rights reserved.
//

#import "EvernoteSession+coda.h"
#import "AuthWindowController.h"
#import <WebKit/WebKit.h>

@implementation EvernoteSession (coda)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (void)verifyCFBundleURLSchemes {
}

- (void)openBrowserWithURL:(NSURL *)url {
  [[AuthWindowController sharedWindowController].webView.mainFrame loadRequest:[NSURLRequest requestWithURL:url]];
}

#pragma clang diagnostic pop
@end

