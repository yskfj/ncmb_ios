/*******
 Copyright 2014 NIFTY Corporation All Rights Reserved.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 **********/

#import "NCMBUser.h"

#import "NCMBAnonymousUtils.h"
#import "NCMBQuery.h"
#import "NCMBACL.h"

#import "NCMBURLConnection.h"

#import "NCMBObject+Private.h"
#import "NCMBObject+Subclass.h"
#import "NCMBRelation+Private.h"


@implementation NCMBUser
#define DATA_MAIN_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"Library/"]
#define DATA_CURRENTUSER_PATH [NSString stringWithFormat:@"%@/Private Documents/NCMB/currentUser", DATA_MAIN_PATH]

#pragma mark - URL
#define URL_LOGIN @"login"
#define URL_LOGOUT @"logout"
#define URL_USERS @"users"
#define URL_AUTHENTICATION_MAIL @"requestMailAddressUserEntry"
#define URL_PASSWOR_RESET  @"requestPasswordReset"



static NCMBUser *currentUser = nil;
static BOOL isEnableAutomaticUser = FALSE;

#pragma mark - init

- (NSDictionary*)getLocalData{
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:[super getLocalData]];
    if (self.userName){
        [dic setObject:self.userName forKey:@"userName"];
    }
    if (self.mailAddress){
        [dic setObject:self.mailAddress forKey:@"mailAddress"];
    }
    if (self.sessionToken){
        [dic setObject:self.sessionToken forKey:@"sessionToken"];
    }
    return dic;
}

//NCMBUserはクラス名を指定しての初期化は出来ない
+ (NCMBObject*)objectWithClassName:(NSString *)className{
    [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot initialize a NCMBUser with a custom class name." userInfo:nil] raise];
    return nil;
}

+ (NCMBUser *)user{
    NCMBUser *user = [[NCMBUser alloc]initWithClassName:@"user"];
    return user;
}

+ (NCMBQuery*)query{
    return [NCMBQuery queryWithClassName:@"user"];
}

#pragma mark - get/set

/**
 ユーザー名の設定
 @param userName ユーザー名
 */
- (void)setUserName:(NSString *)userName{
    [self setObject:userName forKey:@"userName"];
}

/**
 ユーザー名の取得
 @param userName ユーザー名
 @return NSString型ユーザー名
 */
- (NSString *)userName{
    return [self objectForKey:@"userName"];
}

/**
 パスワードの設定
 @param password パスワード
 */
- (void)setPassword:(NSString *)password{
    [self setObject:password forKey:@"password"];
}

/**
 Eメールの設定
 @param mailAddress Eメール
 */
- (void)setMailAddress:(NSString *)mailAddress{
    [self setObject:mailAddress forKey:@"mailAddress"];
}

/**
 Eメールの取得
 @param mailAddress メールアドレス
 @return NSString型メールアドレス
 */
- (NSString *)mailAddress{
    return [self objectForKey:@"mailAddress"];
}

/**
 セッショントークンの設定
 @param ユーザーのセッショントークンを設定する
 */
- (void)setSessionToken:(NSString *)newSessionToken{
    _sessionToken = newSessionToken;
}


/**
 現在ログイン中のユーザーのセッショントークンを返す
 @return NSString型セッショントークン
 */
+ (NSString *)getCurrentSessionToken{
    if (currentUser != nil) {
        return currentUser.sessionToken;
    }
    return nil;
}

/**
 匿名ユーザの自動生成を有効化
 */
+ (void)enableAutomaticUser{
    isEnableAutomaticUser = TRUE;
}

/**
 現在ログインしているユーザ情報を取得
 @return NCMBUser型ログイン中のユーザー
 */
+ (NCMBUser *)currentUser{
    if (currentUser) {
        return currentUser;
    }
    currentUser = nil;
    
    //アプリ再起動などでcurrentUserがnilになった時は端末に保存したユーザ情報を取得、設定する。
    if ([[NSFileManager defaultManager] fileExistsAtPath:DATA_CURRENTUSER_PATH isDirectory:nil]) {
        currentUser = [NCMBUser getFromFileCurrentUser];
    }else{
        //匿名ユーザーの自動生成がYESの時は匿名ユーザーでログインする
        if (isEnableAutomaticUser) {
            isEnableAutomaticUser = NO;
            [NCMBAnonymousUtils logInWithBlock:^(NCMBUser *user, NSError *error) {
                if (!error) {
                    currentUser = user;
                }
                isEnableAutomaticUser = TRUE;
            }];
        }
    }
    
    return currentUser;
}

/**
 認証済みか判定
 @return BOOL型YES=認証済、NO=未認証
 */
- (BOOL)isAuthenticated{
    BOOL isAuthenticateFlag = FALSE;
    if (self.sessionToken) {
        isAuthenticateFlag =TRUE;
    }
    return isAuthenticateFlag;
}

#pragma mark - signUp

/**
 ユーザの新規登録。必要があればエラーをセットし、取得することもできる。
 @param error 処理中に起きたエラーのポインタ
 @return 新規登録の成功の有無
 */
- (BOOL)signUp:(NSError **)error{
    //JSONデータ作成
    NSError *errorLocal;
    NSMutableDictionary *operations = [self beforeConnection];
    NSMutableDictionary *ncmbDic = [self convertToJSONDicFromOperation:operations];
    NSMutableDictionary *jsonDic = [self convertToJSONFromNCMBObject:ncmbDic];
    NSData *json = [NSJSONSerialization dataWithJSONObject:jsonDic options:kNilOptions error:&errorLocal];
    
    //url,method作成
    NSString *url = URL_USERS;
    NSString *method = @"POST";
    if(self.objectId){
        method = @"PUT";
        url = [url stringByAppendingString:[NSString stringWithFormat:@"/%@", self.objectId]];
    }
    
    //通信開始
    NCMBURLConnection *connect = [[NCMBURLConnection new] initWithPath:url method:method data:json];
    NSDictionary *responseDic = [connect syncConnection:&errorLocal];
    
    BOOL isSuccess = YES;
    if(errorLocal){
        isSuccess = NO;
        if (error) {
            *error =  errorLocal;
        }
    }else{
        //レスポンス処理
        [self afterSave:responseDic operations:operations];
        //ファイルに登録したユーザーデータ書き込み
        [NCMBUser saveToFileCurrentUser:self];
    }
    return isSuccess;
}

/**
 ユーザ の新規登録(非同期)
 @param block
 */
- (void)signUpInBackgroundWithBlock:(NCMBBooleanResultBlock)block{
    dispatch_queue_t queue = dispatch_queue_create("saveInBackgroundWithBlock", NULL);
    dispatch_async(queue, ^{
        //JSONデータ作成
        NSError *errorLocal;
        NSMutableDictionary *operations = [self beforeConnection];
        NSMutableDictionary *ncmbDic = [self convertToJSONDicFromOperation:operations];
        NSMutableDictionary *jsonDic = [self convertToJSONFromNCMBObject:ncmbDic];
        NSData *json = [NSJSONSerialization dataWithJSONObject:jsonDic options:kNilOptions error:&errorLocal];
        //url,method作成
        NSString *url = URL_USERS;
        NSString *method = @"POST";
        if(self.objectId){
            method = @"PUT";
            url = [url stringByAppendingString:[NSString stringWithFormat:@"/%@", self.objectId]];
        }
        
        //リクエストを作成
        NCMBURLConnection *request = [[NCMBURLConnection alloc] initWithPath:url method:method data:json];
        //非同期通信を実行
        
        [request asyncConnectionWithBlock:^(NSDictionary *responseDic, NSError *errorBlock){
            BOOL success = YES;
            if (errorBlock){
                success = NO;
            } else {
                //レスポンス処理
                [self afterSave:responseDic operations:operations];
                //ファイルに登録したユーザーデータ書き込み
                [NCMBUser saveToFileCurrentUser:self];
            }
            if(block){
                block(success,errorBlock);
            }
        }];
    });
}


/**
 target用ユーザの新規登録処理
 @param target
 @param selector
 */
- (void)signUpInBackgroundWithTarget:(id)target selector:(SEL)selector{
    NSMethodSignature* signature = [target methodSignatureForSelector: selector ];
    NSInvocation* invocation = [ NSInvocation invocationWithMethodSignature: signature ];
    [ invocation setTarget:target];
    [ invocation setSelector: selector ];
    
    [self signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        NSNumber *num = [NSNumber numberWithBool:succeeded];
        [invocation setArgument:&num  atIndex: 2 ];
        [invocation setArgument:&error atIndex: 3 ];
        [invocation invoke ];
    }];
}

#pragma mark - signUpAnonymous

- (BOOL)signUpFromAnonymous:(NSString *)userName password:(NSString *)password error:(NSError **)error{
    //匿名ユーザーか判定し、正規用ユーザー作成
    NCMBUser *signUpUser = [self checkAnonymousUser];
    //正規ユーザーにデータをセットし、削除用ユーザー作成
    NCMBUser *deleteUser = [self setTheDataForUser:signUpUser userName:userName password:password];
    //新規ユーザー登録
    BOOL success = [signUpUser signUp:error];
    if(!success){
        return success;
    }
    //匿名ユーザー削除
    currentUser = deleteUser;
    success = [deleteUser delete:error];
    currentUser = signUpUser;
    
    return success;
}


- (void)signUpFromAnonymousInBackgroundWithBlock:(NSString *)userName password:(NSString *)password block:(NCMBBooleanResultBlock)block{
    dispatch_queue_t queue = dispatch_queue_create("saveInBackgroundWithBlock", NULL);
    dispatch_async(queue, ^{
        //匿名ユーザーか判定し、正規用ユーザー作成
        NCMBUser *signUpUser = [self checkAnonymousUser];
        //正規ユーザーにデータをセットし、削除用ユーザー作成
        NCMBUser *deleteUser = [self setTheDataForUser:signUpUser userName:userName password:password];
        //新規ユーザー登録
        [signUpUser signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if(error){
                return block(succeeded,error);
            }else{
                //匿名ユーザー削除
                currentUser = deleteUser;
                [deleteUser deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    currentUser = signUpUser;
                    return block(succeeded,error);
                }];
            }
        }];
    });
}

/**
 target用ユーザの新規登録処理
 @param target
 @param selector
 */
- (void)signUpFromAnonymousInBackgroundWithTarget:(NSString *)userName password:(NSString *)password target:(id)target selector:(SEL)selector{
    NSMethodSignature* signature = [target methodSignatureForSelector: selector ];
    NSInvocation* invocation = [ NSInvocation invocationWithMethodSignature: signature ];
    [ invocation setTarget:target];
    [ invocation setSelector: selector ];
    
    [self signUpFromAnonymousInBackgroundWithBlock:userName password:password block:^(BOOL succeeded, NSError *error) {
        NSNumber *num = [NSNumber numberWithBool:succeeded];
        [invocation setArgument:&num  atIndex: 2 ];
        [invocation setArgument:&error atIndex: 3 ];
        [invocation invoke ];
    }];
}

- (NCMBUser *)checkAnonymousUser{
    NCMBUser * anonymousUser = [NCMBUser currentUser];
    if(![NCMBAnonymousUtils isLinkedWithUser:anonymousUser]){
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"This user is not a anonymous user." userInfo:nil] raise];
    }
    return anonymousUser;
}

- (NCMBUser *)setTheDataForUser:(NCMBUser *)signUpUser userName:(NSString *)userName password:(NSString *)password{
    //削除用ユーザー作成
    NCMBUser *deleteUser = [NCMBUser user];
    deleteUser.objectId = signUpUser.objectId;
    deleteUser.sessionToken = signUpUser.sessionToken;
    
    //saiguUp用ユーザー作成。authData以外を引き継ぐ
    [signUpUser removeObjectForKey:@"authData"];
    for(id key in [signUpUser allKeys]){
        [signUpUser setObject:[self convertToJSONFromNCMBObject:[signUpUser objectForKey:key]] forKey:key];
    }
    signUpUser.userName = userName;
    signUpUser.password = password;
    signUpUser.objectId = nil;
    
    return deleteUser;
}

#pragma mark - requestAuthenticationMail

/**
 同期で会員登録メールの要求を行う
 @param email メールアドレス
 @param error エラー
 @return BOOL型通信結果の有無
 */
+ (BOOL)requestAuthenticationMail:(NSString *)email
                            error:(NSError **)error{
    return [NCMBUser requestMailFromNCMB:URL_AUTHENTICATION_MAIL mail:email error:error];
}

/**
 非同期で会員登録メールの要求を行う
 @param email メールアドレス
 @param target
 @param selector
 */
+ (void)requestAuthenticationMailInBackground:(NSString *)email
                                       target:(id)target
                                     selector:(SEL)selector{
    [NCMBUser requestMailFromNCMB:URL_AUTHENTICATION_MAIL mail:email target:target selector:selector];
}

/**
 非同期で会員登録メールの要求を行う
 @param email メールアドレス
 @param block
 */
+ (void)requestAuthenticationMailInBackground:(NSString *)email
                                        block:(NCMBBooleanResultBlock)block{
    [NCMBUser requestMailFromNCMB:URL_AUTHENTICATION_MAIL mail:email block:block];
}


#pragma mark requestMailFromNCMB

/**
 target用ログイン処理
 @param path　パス
 @param email メールアドレス
 @param error エラー
 */
+ (void)requestMailFromNCMB:(NSString *)path
                       mail:(NSString *)email
                     target:(id)target
                   selector:(SEL)selector{
    NSMethodSignature* signature = [target methodSignatureForSelector: selector ];
    NSInvocation* invocation = [ NSInvocation invocationWithMethodSignature: signature ];
    [ invocation setTarget:target];
    [ invocation setSelector: selector ];
    
    NCMBBooleanResultBlock block = ^(BOOL succeeded, NSError *error) {
        NSNumber *num = [NSNumber numberWithBool:succeeded];
        [ invocation setArgument:&num atIndex: 2 ];
        [ invocation setArgument:&error atIndex: 3 ];
        [ invocation invoke ];
    };
    
    if ([path isEqualToString:URL_PASSWOR_RESET]){
        [NCMBUser requestPasswordResetForEmailInBackground:email block:block];
    } else if ([path isEqualToString:URL_AUTHENTICATION_MAIL]){
        [NCMBUser requestAuthenticationMailInBackground:email block:block];
    }
}

/**
 同期メアド要求処理
 @param path　パス
 @param email メールアドレス
 @param error エラー
 */
+ (BOOL)requestMailFromNCMB:(NSString *)path mail:(NSString *)email
                      error:(NSError **)error{
    
    NCMBUser *user = [NCMBUser user];
    user.mailAddress = email;
    
    NSError *errorLocal = nil;
    NSMutableDictionary *operations = [user beforeConnection];
    NSMutableDictionary *ncmbDic = [user convertToJSONDicFromOperation:operations];
    NSMutableDictionary *jsonDic = [user convertToJSONFromNCMBObject:ncmbDic];
    NSData *json = [NSJSONSerialization dataWithJSONObject:jsonDic options:kNilOptions error:&errorLocal];
    
    //通信開始
    NCMBURLConnection *connect = [[NCMBURLConnection new] initWithPath:path method:@"POST" data:json];
    [connect syncConnection:&errorLocal];
    bool isSuccess = YES;
    if (errorLocal) {
        if(error){
            *error = errorLocal;
        }
        isSuccess = NO;
    }
    return isSuccess;
}

/**
 非同期メアド要求処理
 @param path　パス
 @param email　メールアドレス
 @param block
 */
+ (void)requestMailFromNCMB:(NSString *)path
                       mail:(NSString *)email
                      block:(NCMBBooleanResultBlock)block{
    NCMBUser *user = [NCMBUser user];
    user.mailAddress = email;
    
    NSMutableDictionary *operations = [user beforeConnection];
    NSMutableDictionary *ncmbDic = [user convertToJSONDicFromOperation:operations];
    NSMutableDictionary *jsonDic = [user convertToJSONFromNCMBObject:ncmbDic];
    NSData *json = [NSJSONSerialization dataWithJSONObject:jsonDic options:kNilOptions error:nil];
    
    //リクエストを作成
    NCMBURLConnection *request = [[NCMBURLConnection alloc] initWithPath:path method:@"POST" data:json];
    //非同期通信を実行
    [request asyncConnectionWithBlock:^(NSDictionary *responseData, NSError *errorBlock){
        BOOL success = YES;
        if (errorBlock) {
            success = NO;
        }
        if (block) {
            block(success,errorBlock);
        }
    }];
}

#pragma mark - logIn


/**
 同期でログイン(ユーザ名とパスワード)を行う
 @param username　ユーザー名
 @param password　パスワード
 @param error
 */
+ (NCMBUser *)logInWithUsername:(NSString *)username
                       password:(NSString *)password
                          error:(NSError **)error{
    return [NCMBUser ncmbLogIn:username mailAddress:nil password:password error:error];
}

/**
 非同期でログイン(ユーザ名とパスワード)を行う
 @param username　ユーザー名
 @param password　パスワード
 @param target
 @param selector
 */
+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                               target:(id)target
                             selector:(SEL)selector{
    [NCMBUser ncmbLogInInBackground:username mailAddress:nil password:password target:target selector:selector];
}

/**
 非同期でログイン(ユーザ名とパスワード)を行う
 @param username　ユーザー名
 @param password　パスワード
 @param block
 */
+ (void)logInWithUsernameInBackground:(NSString *)username
                             password:(NSString *)password
                                block:(NCMBUserResultBlock)block{
    [NCMBUser ncmbLogInInBackground:username mailAddress:nil password:password block:block];
}

#pragma mark - logInWithMailAddress

/**
 同期でログイン(メールアドレスとパスワード)を行う
 @param email　メールアドレス
 @param password　パスワード
 @param error
 */
+ (NCMBUser *)logInWithMailAddress:(NSString *)email
                          password:(NSString *)password
                             error:(NSError **)error{
    return [NCMBUser ncmbLogIn:nil mailAddress:email password:password error:error];
}

/**
 非同期でログイン(メールアドレスとパスワード)を行う
 @param email　メールアドレス
 @param password　パスワード
 @param target
 @param selector
 */
+ (void)logInWithMailAddressInBackground:(NSString *)email
                                password:(NSString *)password
                                  target:(id)target
                                selector:(SEL)selector{
    [NCMBUser ncmbLogInInBackground:nil mailAddress:email password:password target:target selector:selector];
}


/**
 非同期でログイン(メールアドレスとパスワード)を行う
 @param email　メールアドレス
 @param password　パスワード
 @param block
 */
+ (void)logInWithMailAddressInBackground:(NSString *)email
                                password:(NSString *)password
                                   block:(NCMBUserResultBlock)block{
    [NCMBUser ncmbLogInInBackground:nil mailAddress:email password:password block:block];
}

#pragma mark ncmbLogIn


/**
 targetログイン処理
 @param username　ユーザー名
 @param email　メールアドレス
 @param password　パスワード
 @param target
 @param selector
 */
+ (void)ncmbLogInInBackground:(NSString *)username
                  mailAddress:(NSString *)email
                     password:(NSString *)password
                       target:(id)target
                     selector:(SEL)selector{
    
    NSMethodSignature* signature = [target methodSignatureForSelector: selector ];
    NSInvocation* invocation = [ NSInvocation invocationWithMethodSignature: signature ];
    [ invocation setTarget:target];
    [ invocation setSelector: selector ];
    
    [NCMBUser ncmbLogInInBackground:username mailAddress:email password:password block:^(NCMBUser *user, NSError *error) {
        [ invocation setArgument:&user atIndex: 2 ];
        [ invocation setArgument:&error atIndex: 3 ];
        [ invocation invoke ];
    }];
}

/**
 ログイン用のNCMBURLConnectionを返す
 */
+(NCMBURLConnection*)createConnectionForLogin:(NSString*)username
                                   mailAddress:(NSString*)mailAddress
                                      password:(NSString*)password{
    //検索文字列の作成
    NSMutableArray *queryArray = [NSMutableArray array];
    [queryArray addObject:[NSString stringWithFormat:@"password=%@", password]];
    if ([username length] != 0 && [mailAddress length] == 0){
        [queryArray addObject:[NSString stringWithFormat:@"userName=%@", username]];
    } else if ([username length] == 0 && [mailAddress length] != 0){
        [queryArray addObject:[NSString stringWithFormat:@"mailAddress=%@", mailAddress]];
    }
    NSMutableArray *sortedQueryArray = [NSMutableArray arrayWithArray:[queryArray sortedArrayUsingSelector:@selector(compare:)]];
    
    //pathの作成
    NSString *path = @"";
    for (int i = 0; i< [sortedQueryArray count]; i++){
        if (i == 0){
            path = [path stringByAppendingString:[NSString stringWithFormat:@"%@", sortedQueryArray[i]]];
        } else {
            path = [path stringByAppendingString:[NSString stringWithFormat:@"&%@", sortedQueryArray[i]]];
        }
    }
    NSData *strData = [path dataUsingEncoding:NSUTF8StringEncoding];
    NSString *url = [NSString stringWithFormat:@"login?%@", path];
    return [[NCMBURLConnection alloc] initWithPath:url method:@"GET" data:strData];
}

/**
 同期ログイン処理
 @param username　ユーザー名
 @param email　メールアドレス
 @param password　パスワード
 @param error エラー
 */
+ (NCMBUser *)ncmbLogIn:(NSString *)username
            mailAddress:(NSString *)email
               password:(NSString *)password
                  error:(NSError **)error{
    
    NSError *errorLocal = nil;

    //通信開始
    NCMBURLConnection *connect = [self createConnectionForLogin:username
                                                    mailAddress:email
                                                       password:password];
    NSDictionary * responseData = [connect syncConnection:&errorLocal];
    bool isSuccess = YES;
    NCMBUser *loginUser = nil;
    if (errorLocal) {
        if(error){
            *error = errorLocal;
        }
        isSuccess = NO;
    }else{
        loginUser = [self responseLogIn:responseData];
        [self saveToFileCurrentUser:loginUser];
    }
    return loginUser;
}

/**
 非同期ログイン処理
 @param username　ユーザー名
 @param email　メールアドレス
 @param password　パスワード
 @param block
 */
+ (void)ncmbLogInInBackground:(NSString *)username
                  mailAddress:(NSString *)email
                     password:(NSString *)password
                        block:(NCMBUserResultBlock)block{
    
    //リクエストを作成
    NCMBURLConnection *request = [self createConnectionForLogin:username
                                                    mailAddress:email
                                                       password:password];
    //非同期通信を実行
    [request asyncConnectionWithBlock:^(NSDictionary *responseData, NSError *errorBlock){
        BOOL success = YES;
        NCMBUser *loginUser = nil;
        if (errorBlock) {
            success = NO;
        }else{
            
            loginUser = [self responseLogIn:responseData];
            [self saveToFileCurrentUser:loginUser];
        }
        if (block) {
            block(loginUser,errorBlock);
        }
    }];
}

/**
 ログイン系のレスポンス処理
 @param responseData　サーバーからのレスポンスデータ
 @return NCMBUser型サーバーのデータを反映させたユーザー
 */
+(NCMBUser *)responseLogIn:(NSDictionary *)responseData{
    NCMBUser *loginUser = [NCMBUser user];
    NSMutableDictionary *responseDic = [NSMutableDictionary dictionaryWithDictionary:responseData];
    
    if ([responseDic objectForKey:@"sessionToken"]) {
        loginUser.sessionToken = [responseDic objectForKey:@"sessionToken"];
        [responseDic removeObjectForKey:@"sessionToken"];
    }
    if ([responseDic objectForKey:@"mailAddressConfirm"]) {
        [responseDic removeObjectForKey:@"mailAddressConfirm"];
    }
    [loginUser afterFetch:responseDic isRefresh:YES];
    return loginUser;
}



#pragma mark - logout

/**
 同期でログアウトを行う
 */
+ (void)logOut{
    NSError *errorLocal = nil;
    NCMBURLConnection *connect = [[NCMBURLConnection new] initWithPath:URL_LOGOUT method:@"GET" data:nil];
    [connect syncConnection:&errorLocal];
    if (errorLocal==nil) {
        [self logOutEvent];
    }
}

/**
 ログアウトの処理
 */
+ (void)logOutEvent{
    if (currentUser) {
        currentUser.sessionToken = nil;
        currentUser = nil;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:DATA_CURRENTUSER_PATH isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:DATA_CURRENTUSER_PATH error:nil];
    }
}

#pragma mark requestPasswordResetForEmail

/**
 同期でパスワードリセット要求を行う。
 @param error
 */
+ (BOOL)requestPasswordResetForEmail:(NSString *)email
                               error:(NSError **)error{
    return [NCMBUser requestMailFromNCMB:URL_PASSWOR_RESET mail:email error:error];
}

/**
 非同期でパスワードリセット要求を行う。
 @param target
 @param selector
 */
+ (void)requestPasswordResetForEmailInBackground:(NSString *)email
                                          target:(id)target
                                        selector:(SEL)selector{
    [NCMBUser requestMailFromNCMB:URL_PASSWOR_RESET mail:email target:target selector:selector];
}


/**
 非同期でパスワードリセット要求を行う。
 @param block
 */
+ (void)requestPasswordResetForEmailInBackground:(NSString *)email
                                           block:(NCMBBooleanResultBlock)block{
    [NCMBUser requestMailFromNCMB:URL_PASSWOR_RESET mail:email block:block];
}

#pragma mark - file

+(NCMBUser*)getFromFileCurrentUser{
    NCMBUser *user = [NCMBUser user];
    [user setACL:[[NCMBACL alloc]init]];
    NSError *error = nil;
    NSString *str = [[NSString alloc] initWithContentsOfFile:DATA_CURRENTUSER_PATH encoding:NSUTF8StringEncoding error:&error];
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *dicData = [NSMutableDictionary dictionary];
    if ([data length] != 0){
        dicData = [NSJSONSerialization JSONObjectWithData:data
                                                  options:NSJSONReadingAllowFragments
                                                    error:&error];
    }
    [user afterFetch:[NSMutableDictionary dictionaryWithDictionary:dicData] isRefresh:YES];
    return user;
}

/**
 ログインユーザーをファイルに保存する
 @param NCMBUSer型ファイルに保存するユーザー
 */
+ (void) saveToFileCurrentUser:(NCMBUser *)user {
    if (currentUser != user) {
        [self logOutEvent];
    }
    NSError *e;
    NSMutableDictionary *dic = [user toJSONObjectForDataFile];
    NSData *json = [NSJSONSerialization dataWithJSONObject:dic options:kNilOptions error:&e];
    NSString *strSaveData = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    [strSaveData writeToFile:DATA_CURRENTUSER_PATH atomically:YES encoding:NSUTF8StringEncoding error:&e];
    currentUser = user;
}

/**
 ファイルに書き込むためユーザー情報作成
 @return NSMutableDictionary型ユーザー情報
 */
- (NSMutableDictionary *)toJSONObjectForDataFile{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    
    for (id key in [estimatedData keyEnumerator]) {
        [dic setObject:[self convertToJSONFromNCMBObject:[estimatedData valueForKey:key]] forKey:key];
    }
    if (self.objectId) {
        [dic setObject:self.objectId forKey:@"objectId"];
    }
    if (self.createDate) {
        [dic setObject:self.createDate forKey:@"createDate"];
    }
    if (self.updateDate) {
        [dic setObject:self.updateDate forKey:@"updateDate"];
    }
    if(self.sessionToken){
        [dic setObject:self.sessionToken forKey:@"sessionToken"];
    }
    if (self.ACL) {
        [dic setObject:self.ACL.dicACL forKey:@"acl"];
    }
    return dic;
}


#pragma mark - override

/**
 mobile backendにオブジェクトを保存する
 @param error エラーを保持するポインタ
 @return result 通信が実行されたらYESを返す
 */
- (BOOL)save:(NSError **)error{
    NSString *url = [NSString stringWithFormat:URL_USERS];
    BOOL result = [self save:url error:error];
    return result;
}

/**
 mobile backendにオブジェクトを保存する。非同期通信を行う。
 @param block 通信後に実行されるblock。引数にBOOL succeeded, NSError *errorを持つ。
 */
- (void)saveInBackgroundWithBlock:(NCMBSaveResultBlock)userBlock{
    NSString *url = [NSString stringWithFormat:URL_USERS];
    [self saveInBackgroundWithBlock:url block:userBlock];
}

/**
 オブジェクトをmobile backendとローカル上から削除する
 @param error エラーを保持するポインタを保持するポインタ
 */
- (BOOL)delete:(NSError**)error{
    NSString *url = [NSString stringWithFormat:@"%@/%@",URL_USERS,self.objectId];
    BOOL result = [self delete:url error:error];
    return result;
}

/**
 オブジェクトをmobile backendとローカル上から削除する。非同期通信を行う。
 @param error block 通信後に実行されるblock。引数にBOOL succeeded, NSError *errorを持つ。
 */
- (void)deleteInBackgroundWithBlock:(NCMBDeleteResultBlock)userBlock{
    NSString *url = [NSString stringWithFormat:@"%@/%@",URL_USERS,self.objectId];
    [self deleteInBackgroundWithBlock:url block:userBlock];
}

/**
 ローカルオブジェクトをリセットし、ログアウトする
 */
- (void)afterDelete{
    [super afterDelete];
    [NCMBUser logOutEvent];
}


/**
 mobile backendからobjectIdをキーにしてデータを取得する
 @param error エラーを保持するポインタ
 */
- (BOOL)fetch:(NSError **)error{
    BOOL result = NO;
    if (self.objectId){
        NSString *url = [NSString stringWithFormat:@"%@/%@",URL_USERS,self.objectId];
        result = [self fetch:url error:error isRefresh:NO];
    }
    return result;
}

/**
 mobile backendからobjectIdをキーにしてデータを取得する。非同期通信を行う。
 @param block 通信後に実行されるblock。引数にNSError *errorを持つ。
 */
- (void)fetchInBackgroundWithBlock:(NCMBFetchResultBlock)block{
    NSString *url = [NSString stringWithFormat:@"%@/%@",URL_USERS,self.objectId];
    [self fetchInBackgroundWithBlock:url block:block isRefresh:NO];
}

- (void)afterFetch:(NSMutableDictionary *)response isRefresh:(BOOL)isRefresh{
    if ([response objectForKey:@"userName"]){
        self.userName = [response objectForKey:@"userName"];
    }
    if ([response objectForKey:@"mailAddress"]){
        self.mailAddress = [response objectForKey:@"mailAddress"];
    }
    [super afterFetch:response isRefresh:isRefresh];
}

- (BOOL)refresh:(NSError **)error{
    BOOL resulst = NO;
    if (self.objectId){
        NSString *url = [NSString stringWithFormat:@"%@/%@",URL_USERS,self.objectId];
        resulst = [self fetch:url error:error isRefresh:YES];
    }
    return resulst;
}

- (void)refreshInBackgroundWithBlock:(NCMBFetchResultBlock)block{
    NSString *url = [NSString stringWithFormat:@"%@/%@",URL_USERS,self.objectId];
    [self fetchInBackgroundWithBlock:url block:block isRefresh:YES];
}

/**
 オブジェクト更新後に操作履歴とestimatedDataを同期する
 @param response REST APIのレスポンスデータ
 @param operations 同期する操作履歴
 */
-(void)afterSave:(NSDictionary*)response operations:(NSMutableDictionary *)operations{
    [super afterSave:response operations:operations];
    if ([response objectForKey:@"sessionToken"]){
        self.sessionToken = [response objectForKey:@"sessionToken"];
    }
    //会員新規登録の有無
    if ([response objectForKey:@"createDate"]&&![response objectForKey:@"updateDate"]){
        _isNew = YES;
    }else{
        _isNew = NO;
    }
    
    //SNS連携(匿名ユーザー等はリクエスト時にuserNameを設定しない)時に必要
    if ([response objectForKey:@"userName"]){
        [estimatedData setObject:[response objectForKey:@"userName"] forKey:@"userName"];
    }
    //SNS連携時に必要
    if (![[response objectForKey:@"authData"] isKindOfClass:[NSNull class]]){
        NSDictionary *authDataDic = [response objectForKey:@"authData"];
        NSMutableDictionary *converted = [NSMutableDictionary dictionary];
        for (NSString *key in [[authDataDic allKeys] objectEnumerator]){
            [converted setObject:[self convertToNCMBObjectFromJSON:[authDataDic objectForKey:key]
                                                          convertKey:key]
                            forKey:key];
        }
        [estimatedData setObject:converted forKey:@"authData"];
    }
}

@end
