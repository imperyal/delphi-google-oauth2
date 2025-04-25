//   ===========================================================================
//   Copyright 2020 DCS, Lda
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

//   ============ IMPORTANT ====================================================
//   This unit is inspired on Delphi's OAuth2 code but:
//   - Allows authorization via externel browser
//   - Uses PKCE flow for added security
//   - Allows gereration of new tokens when they expire (using the refresh token)
//   ===========================================================================

{$HPPEMIT LINKUNIT}
unit U_DCS_OAuth2;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Data.Bind.ObjectScope,
  Data.Bind.Components,
  REST.Client,
  REST.Types,
  REST.Consts,
  REST.Utils,
  REST.BindSource,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdContext;

  {$SCOPEDENUMS ON}

const
  K_invalidAuth = 'invalidAuth';

type
  TDCSOAuth2ResponseType = (rtCODE, rtTOKEN);  // rtCODE Default workflow including the authentication of the client - rtTOKEN Implicit workflow for direct requesting an accesstoken
  TDCSOAuth2TokenType    = (ttNONE, ttBEARER);
  TDCSTokenRequestType   = (trtAuthGetTokens, trtRefreshTokens);

  TDCSOAuth2Authenticator     = class;
  TDCSSubOAuth2AuthBindSource = class;
  EOAuth2Exception            = class(ERESTException);
  EOAuth2AuthenticationTimeout = class(EOAuth2Exception);
  EOAuth2AuthenticationFailed = class(EOAuth2Exception);
  EOAuth2AuthenticationCancelled = class(EOAuth2Exception);

  TDCSShowBrowserEvent = procedure(Sender: TDCSOAuth2Authenticator; Url: string) of object;

  TDCSOAuth2Authenticator = class(TCustomAuthenticator)
  private
    { Private declarations }
    FBindSource:            TDCSSubOAuth2AuthBindSource;
    FAccessToken:           string;
    FAccessTokenEndpoint:   string;
    FAccessTokenExpiry:     TDateTime;
    FAccessTokenParamName:  string;
    FAuthCode:              string;
    FAuthenticationTimeout: Cardinal;
    FAuthorizationEndpoint: string;
    FCancelled:             Boolean;
    FClientID:              string;
    FClientSecret:          string;
    FLocalState:            string;
    FCodeVerifier:          string;
    FCodeChallenge:         string;
    FRedirectionEndpoint:   string;
    FRefreshToken:          string;
    FResponseType:          TDCSOAuth2ResponseType;
    FScope:                 string;
    FSync:                  TCriticalSection;
    FTokenType:             TDCSOAuth2TokenType;
    FLoginHint:             string;

    privLS:           TIdHTTPServer;    // LS: Local server (Used to get the Auth code from the localhost redirect by the service provider)
    privLS_port:      integer;
    FPrivTempAuthCode: string;

    FOnShowBrowser: TDCSShowBrowserEvent;

    function  GetCancelled: Boolean;
    function  GetPrivTempAuthCode: string;
    procedure SetAccessTokenEndpoint(const AValue: string);
    procedure SetAccessTokenParamName(const AValue: string);
    procedure SetAuthCode(const AValue: string);
    procedure SetAuthorizationEndpoint(const AValue: string);
    procedure SetClientID(const AValue: string);
    procedure SetClientSecret(const AValue: string);
    procedure SetLocalState(const AValue: string);
    procedure SetPrivTempAuthCode(const AValue: string);
    procedure SetRedirectionEndpoint(const AValue: string);
    procedure SetRefreshToken(const AValue: string);
    procedure SetResponseType(const AValue: TDCSOAuth2ResponseType);
    procedure SetScope(const AValue: string);
    function  ResponseTypeIsStored: Boolean;
    function  TokenTypeIsStored: Boolean;
    function  AccessTokenParamNameIsStored: Boolean;
    procedure ReadAccessTokenExpiryData(AReader: TReader);
    procedure SetAccessToken(const AValue: string);
    procedure SetAccessTokenExpiry(const AExpiry: TDateTime);
    procedure SetTokenType(const AType: TDCSOAuth2TokenType);
    procedure WriteAccessTokenExpiryData(AWriter: TWriter);

    procedure LS_start;
    procedure LS_stop;
    procedure LS_onCommandGet  (AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure LS_onCommandError(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo; AException: Exception);
    function  LS_getMsgPage_html(errorStr: string = ''): string;
    function  LS_getFreePort: integer;

    function  generate_randomString(strLength: integer): string;
    function  encode_SHA256_base64URL(str_toEncode: string): string;

  private
    { Private properties }
    property privTempAuthCode: string read GetPrivTempAuthCode write SetPrivTempAuthCode;

  protected
    { Protected declarations }
    procedure DefineProperties(Filer: TFiler); override;
    procedure DoAuthenticate(ARequest: TCustomRESTRequest); override;
    function  CreateBindSource: TBaseObjectBindSource; override;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Assign(ASource: TDCSOAuth2Authenticator); reintroduce;
    procedure ResetToDefaults; override;

    function  getLocalRedirectionURL_andSetPort: string;
    function  AuthorizationRequestURI: string;

    procedure AquireAccessToken_browser;
    procedure Cancel;
    procedure GetTokens_fromAuthCode;
    procedure GetTokens_fromRefreshToken;
    procedure GetTokens(requestType: TDCSTokenRequestType);

  public
    { Public properties }
    property AuthenticationTimeout: Cardinal read FAuthenticationTimeout write FAuthenticationTimeout default 300000;
    property Cancelled: Boolean read GetCancelled;

  published
    { Published properties }
    property AccessToken:           string     read FAccessToken           write SetAccessToken;
    property AccessTokenEndpoint:   string     read FAccessTokenEndpoint   write SetAccessTokenEndpoint;
    property AccessTokenExpiry:     TDateTime  read FAccessTokenExpiry     write SetAccessTokenExpiry;
    property AccessTokenParamName:  string     read FAccessTokenParamName  write SetAccessTokenParamName stored AccessTokenParamNameIsStored;
    property AuthCode:              string     read FAuthCode              write SetAuthCode;
    property AuthorizationEndpoint: string     read FAuthorizationEndpoint write SetAuthorizationEndpoint;
    property ClientID:              string     read FClientID              write SetClientID;
    property ClientSecret:          string     read FClientSecret          write SetClientSecret;
    property LocalState:            string     read FLocalState            write SetLocalState;
    property CodeVerifier:          string     read FCodeVerifier          write FCodeVerifier;
    property CodeChallenge:         string     read FCodeChallenge         write FCodeChallenge;
    property RedirectionEndpoint:   string     read FRedirectionEndpoint   write SetRedirectionEndpoint;
    property RefreshToken:          string     read FRefreshToken          write SetRefreshToken;
    property ResponseType: TDCSOAuth2ResponseType    read FResponseType    write SetResponseType stored ResponseTypeIsStored;
    property Scope:        string                    read FScope           write SetScope;
    property TokenType:    TDCSOAuth2TokenType       read FTokenType       write SetTokenType stored TokenTypeIsStored;
    property LoginHint:    string                    read FLoginHint       write FLoginHint;
    property BindSource: TDCSSubOAuth2AuthBindSource read FBindSource;

    property OnShowBrowser: TDCSShowBrowserEvent read FOnShowBrowser write FOnShowBrowser;
  end;

  // ***************************************************************************************
  // LiveBindings bindsource for TDCSOAuth2Authenticator. Publishes subcomponent properties
  TDCSSubOAuth2AuthBindSource = class(TRESTAuthenticatorBindSource<TDCSOAuth2Authenticator>)
  protected
    function CreateAdapterT: TRESTAuthenticatorAdapter<TDCSOAuth2Authenticator>; override;
  end;

  // ***********************************************************************
  /// LiveBindings adapter for TOAuth2Authenticator. Create bindable members
  TDCSOAuth2AuthAdapter = class(TRESTAuthenticatorAdapter<TDCSOAuth2Authenticator>)
  protected
    procedure AddFields; override;
  end;


  function DCSOAuth2ResponseTypeToString  (const AType: TDCSOAuth2ResponseType): string;
  function DCSOAuth2ResponseTypeFromString(const ATypeString: string): TDCSOAuth2ResponseType;

  function DCSOAuth2TokenTypeToString  (const AType: TDCSOAuth2TokenType): string;
  function DCSOAuth2TokenTypeFromString(const ATypeString: string): TDCSOAuth2TokenType;

var
  DefaultOAuth2ResponseType:         TDCSOAuth2ResponseType = TDCSOAuth2ResponseType.rtCODE;
  DefaultOAuth2TokenType:            TDCSOAuth2TokenType    = TDCSOAuth2TokenType.ttNONE;
  DefaultOAuth2AccessTokenParamName: string                 = 'access_token'; // do not localize


implementation

uses
  System.DateUtils, System.NetEncoding,
  Winapi.Windows, Winapi.ShellAPI, Win.ScktComp,
  IdHashSHA, IdSSLOpenSSL, IdGlobal;



{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
{ ******* //                                                     // ******* }
{ ******* //             TDCSOAuth2Authenticator                 // ******* }
{ ******* //                                                     // ******* }
{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
constructor TDCSOAuth2Authenticator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  self.ResetToDefaults;
  FAuthenticationTimeout := 300000; // 5 minutes
  FSync := TCriticalSection.Create;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
destructor TDCSOAuth2Authenticator.Destroy;
begin
  FSync.Free;
  inherited;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.CreateBindSource: TBaseObjectBindSource;
begin
  self.FBindSource := TDCSSubOAuth2AuthBindSource.Create(self);
  self.FBindSource.Name := 'BindSource'; { Do not localize }
  self.FBindSource.SetSubComponent(True);
  self.FBindSource.Authenticator := self;

  result := self.FBindSource;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.AccessTokenParamNameIsStored: Boolean;
begin
  result := self.AccessTokenParamName <> DefaultOAuth2AccessTokenParamName;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.Assign(ASource: TDCSOAuth2Authenticator);
begin
  self.ResetToDefaults;

  self.ClientID              := ASource.ClientID;
  self.ClientSecret          := ASource.ClientSecret;
  self.AuthCode              := ASource.AuthCode;
  self.AccessToken           := ASource.AccessToken;
  self.AccessTokenParamName  := ASource.AccessTokenParamName;

  self.AccessTokenExpiry     := ASource.AccessTokenExpiry;

  self.Scope                 := ASource.Scope;
  self.RefreshToken          := ASource.RefreshToken;
  self.LocalState            := ASource.LocalState;

  self.TokenType             := ASource.TokenType;

  self.ResponseType          := ASource.ResponseType;
  self.AuthorizationEndpoint := ASource.AuthorizationEndpoint;
  self.AccessTokenEndpoint   := ASource.AccessTokenEndpoint;
  self.RedirectionEndpoint   := ASource.RedirectionEndpoint;

  FAuthenticationTimeout     := ASource.FAuthenticationTimeout;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.AuthorizationRequestURI: string;
var
  respTypeStr: string;
begin
  respTypeStr := DCSOAuth2ResponseTypeToString(self.FResponseType);

  result := self.FAuthorizationEndpoint;
  if true                            then result := result + '?response_type=' + URIEncode(respTypeStr);
  if self.FClientID            <> '' then result := result + '&client_id='     + URIEncode(self.FClientID);
  if self.FRedirectionEndpoint <> '' then result := result + '&redirect_uri='  + URIEncode(self.FRedirectionEndpoint);
  if self.FScope               <> '' then result := result + '&scope='         + URIEncode(self.FScope);
  if self.FLocalState          <> '' then result := result + '&state='         + URIEncode(self.FLocalState);
  if self.FLoginHint           <> '' then result := result + '&login_hint='    + URIEncode(self.FLoginHint);

  if self.FCodeChallenge <> '' then
     begin
     result := result + '&code_challenge_method=' + URIEncode('S256');
     result := result + '&code_challenge='        + URIEncode(self.FCodeChallenge);
     end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.GetCancelled: Boolean;
begin
  FSync.Acquire;
  try
    Result := FCancelled;
  finally
    FSync.Release;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.GetPrivTempAuthCode: string;
begin
  FSync.Acquire;
  try
    Result := FPrivTempAuthCode;
  finally
    FSync.Release;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
// Get the tokens using the authorization code
procedure TDCSOAuth2Authenticator.GetTokens_fromAuthCode;
begin
  self.GetTokens(TDCSTokenRequestType.trtAuthGetTokens);
end;

{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
// Get new tokens using the refresh token
// - Call if the access token is expired
procedure TDCSOAuth2Authenticator.GetTokens_fromRefreshToken;
begin
  self.GetTokens(TDCSTokenRequestType.trtRefreshTokens);
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.GetTokens(requestType: TDCSTokenRequestType);
var
  restClient:      TRestClient;
  restRequest:     TRESTRequest;
  get_fromAuth:    boolean;
  get_fremRefresh: boolean;
  respValueStr:    string;
  expireSecs:      int64;
begin
  get_fromAuth    := (requestType = TDCSTokenRequestType.trtAuthGetTokens);
  get_fremRefresh := (requestType = TDCSTokenRequestType.trtRefreshTokens);

  if get_fromAuth    and (FAuthCode     = '') then raise EOAuth2Exception.Create(SAuthorizationCodeNeeded);  // AuthCode     is needed to send it to the servce and exchange the code into an access-token
  if get_fremRefresh and (FRefreshToken = '') then raise EOAuth2Exception.Create('Empty RefreshToken');      // RefreshToken is needed to refresh the access-token

  restClient := TRestClient.Create(FAccessTokenEndpoint);
  try
    restRequest        := TRESTRequest.Create(restClient); // The restClient now "owns" the Request and will free it.
    restRequest.Method := TRESTRequestMethod.rmPOST;

    // Add parameters to the request
    restRequest.AddAuthParameter('client_id',     self.FClientID,            TRESTRequestParameterKind.pkGETorPOST);
    restRequest.AddAuthParameter('client_secret', self.FClientSecret,        TRESTRequestParameterKind.pkGETorPOST);
    restRequest.AddAuthParameter('redirect_uri',  self.FRedirectionEndpoint, TRESTRequestParameterKind.pkGETorPOST);

    if get_fromAuth then
       begin
       restRequest.AddAuthParameter('code',          self.FAuthCode,       TRESTRequestParameterKind.pkGETorPOST);
       restRequest.AddAuthParameter('code_verifier', self.FCodeVerifier,   TRESTRequestParameterKind.pkGETorPOST);     // Added for PKCE
       restRequest.AddAuthParameter('grant_type',    'authorization_code', TRESTRequestParameterKind.pkGETorPOST);
       end else
    if get_fremRefresh then
       begin
       restRequest.AddAuthParameter('refresh_token', self.FRefreshToken,   TRESTRequestParameterKind.pkGETorPOST);
       restRequest.AddAuthParameter('grant_type',    'refresh_token',      TRESTRequestParameterKind.pkGETorPOST);
       end;

    // Make the request
    restRequest.Execute;

    // Get Tokens from response
    if restRequest.Response.GetSimpleValue('access_token',  respValueStr) then self.FAccessToken  := respValueStr;
    if restRequest.Response.GetSimpleValue('refresh_token', respValueStr) then self.FRefreshToken := respValueStr;
    if restRequest.Response.GetSimpleValue('token_type',    respValueStr) then self.FTokenType    := DCSOAuth2TokenTypeFromString(respValueStr);   // token-type is important for how using it later on the normal requests to the API

    // Get token exipancy if provided by the service (value in secounds)
    if restRequest.Response.GetSimpleValue('expires_in', respValueStr) then
       begin
       expireSecs := StrToIntdef(respValueStr, -1);
       if (expireSecs > -1)
          then self.FAccessTokenExpiry := IncSecond(Now, expireSecs)
          else self.FAccessTokenExpiry := 0.0;
       end;

    // Clear AuthCode (can only be used once)
    if get_fromAuth and (self.FAccessToken <> '') then
       self.FAuthCode := '';

  finally
    restClient.Free;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
// Request user authorization (using the browser) to get an authCode
// Use the authCode to get the AccessToken and RefreshToken
procedure TDCSOAuth2Authenticator.AquireAccessToken_browser;
var
  authStartTick: Cardinal;
  url: string;
begin
  if (self.FClientID     = '') then raise Exception.Create('ClientID required');
  if (self.FClientSecret = '') then raise Exception.Create('ClientSecret required');

  // Generate verification codes
  self.FLocalState    := self.generate_randomString(10);              // LocalState
  self.FCodeVerifier  := self.generate_randomString(60);              // PKCE
  self.FCodeChallenge := self.encode_SHA256_base64URL(FCodeVerifier); // PKCE

  // Get URL with queryString to open in the browser
  url := self.AuthorizationRequestURI;

  //*******************
  // Start Local Server
  // - the http server waits for the user to authorize
  // - then google redirects the browser to the local RedirectionEndpoint provided adding the AuthCode on its queryParams
  privTempAuthCode := '';  // Clear
  FCancelled := False;
  self.LS_start;

  //*******************************
  // Get authorization
  // - if 'FOnShowBrowser' is set, let the application handle opening the browser. Otherwise, open the link directly.
  try
    if Assigned(FOnShowBrowser) then
      FOnShowBrowser(self, url)
    else
      ShellExecute(0, 'open', PChar(url), nil, nil, SW_SHOWNORMAL);

    //****************************************
    // User will have N milliseconds to authorize. When 'privTempAuthCode' is set, we have the auth code
    authStartTick := GetTickCount;
    repeat
      if (GetTickCount - authStartTick >= FAuthenticationTimeout) then
        raise EOAuth2AuthenticationTimeout.Create('Authentication timed out');

      if Cancelled then
        raise EOAuth2AuthenticationCancelled.Create('Authentication cancelled');

      Sleep(250);
    until (privTempAuthCode <> '');
  finally
    //******************
    // Stop Local Server
    self.LS_stop;
  end;

  if privTempAuthCode <> K_invalidAuth then
     self.FAuthCode := privTempAuthCode;

  if (self.FAuthCode = '')
     then raise EOAuth2AuthenticationFailed.Create('Authentication failed');

  //******************************
  // Get Tokens using the AuthCode
  self.GetTokens_fromAuthCode();

  if (self.FAccessToken = '') then
    raise EOAuth2Exception.Create('Failed to aquire access token');
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.Cancel;
begin
  FSync.Acquire;
  try
    FCancelled := True;
  finally
    FSync.Release;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.getLocalRedirectionURL_andSetPort: string;
begin
  self.privLS_port := self.LS_getFreePort;
  result           := 'http://127.0.0.1:' + intToStr(self.privLS_port);
end;



{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.LS_getFreePort: integer;
begin
  with TServerSocket.Create(self) do
       begin
       Port   := 0;
       Active := true;
       result := Socket.LocalPort;
       Active := false;

       Free;
       end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.LS_start;
begin
  if privLS <> nil then raise Exception.Create('Error on LS_start');

  privLS := TIdHTTPServer.Create(nil);

  privLS.Active         := false;
  privLS.DefaultPort    := self.privLS_port;
  privLS.OnCommandGet   := LS_onCommandGet;
  privLS.OnCommandError := LS_onCommandError;
  privLS.Active         := true;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.LS_stop;
begin
  privLS.Active := false;
  FreeAndNil(privLS);
end;




{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
// This event runs when the Local Server processes a GET request
// - When the user accepts (or not) the request for authorization in the browser
//   the service (Google) calls the redirect URL provided earlier
// - In this case we the localhost URL
// - The service adds the AuthCode to the URL with a query string named "code"
procedure TDCSOAuth2Authenticator.LS_onCommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  getCode:   boolean;
  errorHtml: string;
  codeStr:   string;
  stateStr:  string;
begin

  if ARequestInfo.QueryParams = '' then exit;   // The request has to have query strings
  if privTempAuthCode        <> '' then exit;   // Exit if the AuthCode was already captured

  // Obter erro caso exista
  errorHtml := ARequestInfo.Params.Values['error'];
  getCode   := (errorHtml = '');

  //***************
  // Obter AuthCode
  if getCode then
     begin
     codeStr  := ARequestInfo.Params.Values['code'];
     stateStr := ARequestInfo.Params.Values['state'];

     if stateStr = self.FLocalState then  // Value LocalState was sent to the browser and have to return unchanged
        privTempAuthCode := codeStr;
     end;


  if privTempAuthCode = '' then
     privTempAuthCode := K_invalidAuth;

  //***********************************
  // Set HTML response (to the browser)
  if (privTempAuthCode = K_invalidAuth) and (errorHtml = '') then
     errorHtml := 'Auth code not found';

  if privTempAuthCode = K_invalidAuth then AResponseInfo.ContentText := self.LS_getMsgPage_html(errorHtml)
                                      else AResponseInfo.ContentText := self.LS_getMsgPage_html('');
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.LS_onCommandError(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo; AException: Exception);
begin
  privTempAuthCode := K_invalidAuth;
  raise EOAuth2Exception.Create('LS_onCommandError: ' + AException.Message);
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.LS_getMsgPage_html(errorStr: string = ''): string;
resourcestring
  RS_LS_page_ok    = 'Authorization OK';
  RS_LS_page_error = 'Authorization Fail';
  RS_LS_ok_tit     = 'The authorization has succeeded';
  RS_LS_ok_msg     = 'You can close this page and return to the application.';
  RS_LS_error_tit  = 'Something went wrong...';
  RS_LS_error_msg  = 'You can close this page and return to the application to try again.';
const
  K_HTML_doc = '<html><head><title>%s</title><meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /></head>' +
                '<body><p>&nbsp;</p><p>&nbsp;</p>' +
                '<hr />' +
                '%s' +
                '<hr />' +
                '<p>&nbsp;</p></body></html>';
  K_HTML_h3_green = '<h3 style="text-align:center; font-family:Tahoma,Geneva,sans-serif; color:#16a085; font-weight: bold;">%s</h3>';
  K_HTML_h3_red   = '<h3 style="text-align:center; font-family:Tahoma,Geneva,sans-serif; color:#c0392b; font-weight: bold;">%s</h3>';
  K_HTML_P        = '<p  style="text-align:center; font-family:Tahoma,Geneva,sans-serif">%s</p>';
var
  errorPage: boolean;
  h3_html:   string;
  p1_html:   string;
  p2_html:   string;
  page_title:   string;
  page_content: string;
begin
  errorPage := errorStr <> '';

  if errorPage
     then begin
          h3_html := THTMLEncoding.HTML.Encode(RS_LS_error_tit);
          p1_html := THTMLEncoding.HTML.Encode(RS_LS_error_msg);
          p2_html := THTMLEncoding.HTML.Encode(errorStr);

          h3_html := format(K_HTML_h3_red, [h3_html]);
          p1_html := format(K_HTML_p,      [p1_html]);
          p2_html := format(K_HTML_p,      [p2_html]);

          page_title   := RS_LS_page_error;
          page_content := h3_html + p1_html + p2_html;
          end
     else begin
          h3_html := THTMLEncoding.HTML.Encode(RS_LS_ok_tit);
          p1_html := THTMLEncoding.HTML.Encode(RS_LS_ok_msg);

          h3_html := format(K_HTML_h3_green, [h3_html]);
          p1_html := format(K_HTML_p,        [p1_html]);

          page_title   := RS_LS_page_ok;
          page_content := h3_html + p1_html;
          end;

  result := format(K_HTML_doc, [page_title, page_content]);
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.generate_randomString(strLength: integer): string;
const
  K_charsToUse = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-._~';
var
  i:              integer;
  allChars_count: integer;
  curCharPos:     byte;
begin
  allChars_count := Length(K_charsToUse);

  SetLength(result, strLength);
  Randomize;

  for i := 1 to strLength do
      begin
      curCharPos := Random(allChars_count) + 1;    // +1 becouse strings start in 1 and Random generates values of 0 <= X < Range
      result[i]  := K_charsToUse[curCharPos];
      end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.encode_SHA256_base64URL(str_toEncode: string): string;
var
  hash_sha256: TIdHashSHA256;
  enc_base64:  TBase64Encoding;
  arr_sha256:  TIdBytes;
  str_b64:     string;
  str_b64URL:  string;
begin
  result := '';

  LoadOpenSSLLibrary;
  if not TIdHashSHA256.IsAvailable then raise Exception.Create('Error encode_SHA256_base64URL: TIdHashSHA256 not available.');

  hash_sha256 := TIdHashSHA256.Create;
  enc_base64 := TBase64Encoding.Create(0);

  try
    arr_sha256 := hash_sha256.HashString(str_toEncode, IndyTextEncoding_ASCII); // Hash SHA256
    str_b64    := enc_base64.EncodeBytesToString(arr_sha256);                   // Convert SHA256 hash to Base64

    // Convert Base64 to Base64URL
    str_b64URL := str_b64;
    str_b64URL := StringReplace(str_b64URL, '+', '-', [rfReplaceAll]);    // Replace + with -
    str_b64URL := StringReplace(str_b64URL, '/', '_', [rfReplaceAll]);    // Replace / with _
    str_b64URL := StringReplace(str_b64URL, '=', '',  [rfReplaceAll]);    // Remove padding, character =

    result := str_b64URL;
  finally
    enc_base64.Free;
    hash_sha256.Free;
  end;
end;



{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.DefineProperties(Filer: TFiler);
begin
  inherited;

  Filer.DefineProperty('AccessTokenExpiryDate',
                       self.ReadAccessTokenExpiryData,
                       self.WriteAccessTokenExpiryData,
                       (self.FAccessTokenExpiry > 0.1));
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
// The procedure runs on every API request
// Flow:
// 1. If no access_token is defined, the browser auth process is started
// 2. If tokens are expired, get new ones using the RefreshToken
// 3. Add the access_token to the request
procedure TDCSOAuth2Authenticator.DoAuthenticate(ARequest: TCustomRESTRequest);
var
  accessParamName: string;
begin
  inherited;

  // Get or refresh the tokens if needed
  if self.FAccessToken = ''        then self.AquireAccessToken_browser;
  if self.FAccessTokenExpiry < now then self.GetTokens_fromRefreshToken;

  // Use another parameter name for the access_token if necessary
  // - Only used when the token type is not Bearer
  accessParamName := self.FAccessTokenParamName;
  if (Trim(accessParamName) = '') then
     accessParamName := DefaultOAuth2AccessTokenParamName;

  // Add AccessToken to the request
  if self.FTokenType = TDCSOAuth2TokenType.ttBEARER
     then ARequest.AddAuthParameter(HTTP_HEADERFIELD_AUTH, 'Bearer ' + self.FAccessToken, TRESTRequestParameterKind.pkHTTPHEADER, [TRESTRequestParameterOption.poDoNotEncode])
     else ARequest.AddAuthParameter(accessParamName,                   self.FAccessToken, TRESTRequestParameterKind.pkGETorPOST,  [TRESTRequestParameterOption.poDoNotEncode]);
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.ReadAccessTokenExpiryData(AReader: TReader);
begin
  self.FAccessTokenExpiry := AReader.ReadDate;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.ResetToDefaults;
begin
  inherited;

  self.AuthorizationEndpoint := '';
  self.AccessTokenEndpoint   := '';
  self.RedirectionEndpoint   := '';

  self.ClientID           := '';
  self.ClientSecret       := '';
  self.AuthCode           := '';
  self.AccessToken        := '';
  self.FAccessTokenExpiry := 0.0;
  self.Scope              := '';
  self.RefreshToken       := '';
  self.LocalState         := '';
  self.LoginHint          := '';
  self.CodeVerifier       := '';
  self.CodeChallenge      := '';

  self.FTokenType            := DefaultOAuth2TokenType;
  self.ResponseType          := DefaultOAuth2ResponseType;
  self.AccessTokenParamName  := DefaultOAuth2AccessTokenParamName;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.ResponseTypeIsStored: Boolean;
begin
  Result := self.ResponseType <> DefaultOAuth2ResponseType;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetAccessToken(const AValue: string);
begin
  if AValue <> FAccessToken then
  begin
    FAccessToken := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetAccessTokenEndpoint(const AValue: string);
begin
  if AValue <> FAccessTokenEndpoint then
  begin
    FAccessTokenEndpoint := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetAccessTokenExpiry(const AExpiry: TDateTime);
begin
  if AExpiry <> FAccessTokenExpiry then
  begin
    FAccessTokenExpiry := AExpiry;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetAccessTokenParamName(const AValue: string);
begin
  if AValue <> FAccessTokenParamName then
  begin
    FAccessTokenParamName := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetAuthCode(const AValue: string);
begin
  if AValue <> FAuthCode then
  begin
    FAuthCode := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetAuthorizationEndpoint(const AValue: string);
begin
  if AValue <> FAuthorizationEndpoint then
  begin
    FAuthorizationEndpoint := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetClientID(const AValue: string);
begin
  if AValue <> FClientID then
  begin
    FClientID := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetClientSecret(const AValue: string);
begin
  if AValue <> FClientSecret then
  begin
    FClientSecret := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetLocalState(const AValue: string);
begin
  if AValue <> FLocalState then
  begin
    FLocalState := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetPrivTempAuthCode(const AValue: string);
begin
  FSync.Acquire;
  try
    FPrivTempAuthCode := AValue;
  finally
    FSync.Release;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetRedirectionEndpoint(const AValue: string);
begin
  if AValue <> FRedirectionEndpoint then
  begin
    FRedirectionEndpoint := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetRefreshToken(const AValue: string);
begin
  if AValue <> FRefreshToken then
  begin
    FRefreshToken := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetResponseType(const AValue: TDCSOAuth2ResponseType);
begin
  if AValue <> FResponseType then
  begin
    FResponseType := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetScope(const AValue: string);
begin
  if AValue <> FScope then
  begin
    FScope := AValue;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.SetTokenType(const AType: TDCSOAuth2TokenType);
begin
  if AType <> FTokenType then
  begin
    FTokenType := AType;
    PropertyValueChanged;
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSOAuth2Authenticator.TokenTypeIsStored: Boolean;
begin
  Result := TokenType <> DefaultOAuth2TokenType;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2Authenticator.WriteAccessTokenExpiryData(AWriter: TWriter);
begin
  AWriter.WriteDate(FAccessTokenExpiry);
end;







{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
{ ******* //                                                     // ******* }
{ ******* //             TDCSSubOAuth2AuthBindSource             // ******* }
{ ******* //                                                     // ******* }
{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function TDCSSubOAuth2AuthBindSource.CreateAdapterT: TRESTAuthenticatorAdapter<TDCSOAuth2Authenticator>;
begin
  result := TDCSOAuth2AuthAdapter.Create(self);
end;







{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
{ ******* //                                                     // ******* }
{ ******* //               TDCSOAuth2AuthAdapter                 // ******* }
{ ******* //                                                     // ******* }
{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
procedure TDCSOAuth2AuthAdapter.AddFields;
const
  sAccessToken           = 'AccessToken';
  sAccessTokenEndpoint   = 'AccessTokenEndpoint';
  sRefreshToken          = 'RefreshToken';
  sAuthCode              = 'AuthCode';
  sClientID              = 'ClientID';
  sClientSecret          = 'ClientSecret';
  sAuthorizationEndpoint = 'AuthorizationEndpoint';
  sRedirectionEndpoint   = 'RedirectionEndpoint';
  sScope                 = 'Scope';
  sLocalState            = 'LocalState';
  sCodeVerifier          = 'CodeVerifier';
  sCodeChallenge         = 'CodeChallenge';
  sLoginHint             = 'LoginHint';
var
  LGetMemberObject: IGetMemberObject;
begin
  CheckInactive;
  ClearFields;
  if Authenticator <> nil then
  begin
    LGetMemberObject := TBindSourceAdapterGetMemberObject.Create(self);

    CreateReadWriteField<string>(sAccessToken, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.AccessToken;
      end,
      procedure(AValue: string)
      begin
        Authenticator.AccessToken := AValue;
      end);

    CreateReadWriteField<string>(sAccessTokenEndpoint, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.AccessTokenEndpoint;
      end,
      procedure(AValue: string)
      begin
        Authenticator.AccessTokenEndpoint := AValue;
      end);

    CreateReadWriteField<string>(sRefreshToken, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.RefreshToken;
      end,
      procedure(AValue: string)
      begin
        Authenticator.RefreshToken := AValue;
      end);

    CreateReadWriteField<string>(sAuthCode, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.AuthCode;
      end,
      procedure(AValue: string)
      begin
        Authenticator.AuthCode := AValue;
      end);

    CreateReadWriteField<string>(sClientID, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.ClientID;
      end,
      procedure(AValue: string)
      begin
        Authenticator.ClientID := AValue;
      end);

    CreateReadWriteField<string>(sClientSecret, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.ClientSecret;
      end,
      procedure(AValue: string)
      begin
        Authenticator.ClientSecret := AValue;
      end);

    CreateReadWriteField<string>(sAuthorizationEndpoint, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.AuthorizationEndpoint;
      end,
      procedure(AValue: string)
      begin
        Authenticator.AuthorizationEndpoint := AValue;
      end);

    CreateReadWriteField<string>(sRedirectionEndpoint, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.RedirectionEndpoint;
      end,
      procedure(AValue: string)
      begin
        Authenticator.RedirectionEndpoint := AValue;
      end);

    CreateReadWriteField<string>(sScope, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.Scope;
      end,
      procedure(AValue: string)
      begin
        Authenticator.Scope := AValue;
      end);

    CreateReadWriteField<string>(sLocalState, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.LocalState;
      end,
      procedure(AValue: string)
      begin
        Authenticator.LocalState := AValue;
      end);

    CreateReadWriteField<string>(sCodeVerifier, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.CodeVerifier;
      end,
      procedure(AValue: string)
      begin
        Authenticator.CodeVerifier := AValue;
      end);

    CreateReadWriteField<string>(sCodeChallenge, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.CodeChallenge;
      end,
      procedure(AValue: string)
      begin
        Authenticator.CodeChallenge := AValue;
      end);

    CreateReadWriteField<string>(sLoginHint, LGetMemberObject, TScopeMemberType.mtText,
      function: string
      begin
        result := Authenticator.LoginHint;
      end,
      procedure(AValue: string)
      begin
        Authenticator.LoginHint := AValue;
      end);
  end;
end;







{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
{ ******* //                                                     // ******* }
{ ******* //                   Unit functions                    // ******* }
{ ******* //                                                     // ******* }
{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }

{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function DCSOAuth2ResponseTypeToString(const AType: TDCSOAuth2ResponseType): string;
begin
  case AType of
    TDCSOAuth2ResponseType.rtCODE:  result := 'code'; // do not localize
    TDCSOAuth2ResponseType.rtTOKEN: result := 'token'; // do not localize
  else
    result := '';
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function DCSOAuth2ResponseTypeFromString(const ATypeString: string): TDCSOAuth2ResponseType;
var
  LType: TDCSOAuth2ResponseType;
begin
  result := DefaultOAuth2ResponseType;

  for LType IN [Low(TDCSOAuth2ResponseType)..High(TDCSOAuth2ResponseType)] do
      if SameText(ATypeString, DCSOAuth2ResponseTypeToString(LType)) then
         begin
         result := LType;
         BREAK;
         end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function DCSOAuth2TokenTypeToString(const AType: TDCSOAuth2TokenType): string;
begin
  case AType of
    TDCSOAuth2TokenType.ttBEARER: result := 'bearer'; // do not localize
  else
    result := '';
  end;
end;


{ ******* // ******* // ******* // ******* // ******* // ******* // ******* }
function DCSOAuth2TokenTypeFromString(const ATypeString: string): TDCSOAuth2TokenType;
var
  LType: TDCSOAuth2TokenType;
begin
  result := DefaultOAuth2TokenType;

  for LType IN [Low(TDCSOAuth2TokenType) .. High(TDCSOAuth2TokenType)] do
    if SameText(ATypeString, DCSOAuth2TokenTypeToString(LType)) then
       begin
       result := LType;
       BREAK;
       end;
end;


initialization

end.
