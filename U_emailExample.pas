unit U_emailExample;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  U_DCS_OAuth2, IdBaseComponent, IdMessage;

const
  K_tokens_file     = 'tokens.txt';
  K_token_expirancy = 'token_expirancy';
  K_token_access    = 'token_access';
  K_token_refresh   = 'token_refresh';

type
  TFRM_sendMail = class(TForm)
    EDT_email_google: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    EDT_toEmail: TEdit;
    Label4: TLabel;
    EDT_toSubject: TEdit;
    MEM_toMessage: TMemo;
    Label5: TLabel;
    BUT_send: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BUT_sendClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    TSL_tokens: tStringList;

    privAppPath: string;
    DCSOAuth2Authenticator: TDCSOAuth2Authenticator;

    procedure prepareAuthenticator(senderEmail: string; clearTokens: boolean = false);
    procedure emailSender_send_viaGmail;
    function  getEmailMessage_fromForm: tIdMessage;

    procedure loadOptions;
    procedure saveOptions;
  public
    { Public declarations }
  end;

var
  FRM_sendMail: TFRM_sendMail;

implementation

{$R *.dfm}

uses
  REST.Client, REST.Types, System.JSON, Web.HTTPApp, IdText, dateUtils;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.FormCreate(Sender: TObject);
var
  unix_exp:    Int64;
  unix_onFile: string;
begin
  TSL_tokens             := tStringList.Create;
  DCSOAuth2Authenticator := TDCSOAuth2Authenticator.Create(nil);

  privAppPath := Application.ExeName;
  privAppPath := ExtractFilePath(privAppPath);

  self.loadOptions;
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.FormDestroy(Sender: TObject);
begin
  self.saveOptions;

  DCSOAuth2Authenticator.Free;
  TSL_tokens.Free;
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.BUT_sendClick(Sender: TObject);
begin
  self.emailSender_send_viaGmail;

  ShowMessage('The email was sent.');
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.loadOptions;
var
  unix_exp:    Int64;
  unix_onFile: string;
begin
  if FileExists(privAppPath + K_tokens_file) then
     begin
     // Open tokens file
     TSL_tokens.LoadFromFile(privAppPath + K_tokens_file);

     // Load previousely obtained tokens
     unix_onFile := TSL_tokens.Values[K_token_expirancy];
     if unix_onFile = ''
        then unix_exp := DateTimeToUnix(now, false)
        else unix_exp := StrToInt64(unix_onFile);

     DCSOAuth2Authenticator.AccessToken       := TSL_tokens.Values[K_token_access];
     DCSOAuth2Authenticator.RefreshToken      := TSL_tokens.Values[K_token_refresh];
     DCSOAuth2Authenticator.AccessTokenExpiry := UnixToDateTime(unix_exp, false);

     // Load other options
     EDT_email_google.Text := TSL_tokens.Values[EDT_email_google.Name];
     EDT_toEmail.Text      := TSL_tokens.Values[EDT_toEmail.Name];
     EDT_toSubject.Text    := TSL_tokens.Values[EDT_toSubject.Name];
     end;
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.saveOptions;
var
  unix_exp:    Int64;
  unix_expStr: string;
begin
  // Save corrent tokens
  unix_exp    := DateTimeToUnix(DCSOAuth2Authenticator.AccessTokenExpiry, false);
  unix_expStr := IntToStr(unix_exp);
  TSL_tokens.Values[K_token_access]    := DCSOAuth2Authenticator.AccessToken;
  TSL_tokens.Values[K_token_refresh]   := DCSOAuth2Authenticator.RefreshToken;
  TSL_tokens.Values[K_token_expirancy] := unix_expStr;

  // Save other options
  TSL_tokens.Values[EDT_email_google.Name] := EDT_email_google.Text;
  TSL_tokens.Values[EDT_toEmail.Name]      := EDT_toEmail.Text;
  TSL_tokens.Values[EDT_toSubject.Name]    := EDT_toSubject.Text;

  // Save to tokens file
  TSL_tokens.SaveToFile(privAppPath + K_tokens_file);
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.prepareAuthenticator(senderEmail: string; clearTokens: boolean = false);
begin
  if clearTokens then
     DCSOAuth2Authenticator.ResetToDefaults;    // Reset tokens

  // General options
  DCSOAuth2Authenticator.AccessTokenEndpoint   := 'https://www.googleapis.com/oauth2/v4/token';
  DCSOAuth2Authenticator.AuthorizationEndpoint := 'https://accounts.google.com/o/oauth2/v2/auth';
  DCSOAuth2Authenticator.ResponseType          := TDCSOAuth2ResponseType.rtCODE;
  DCSOAuth2Authenticator.Scope                 := 'https://www.googleapis.com/auth/gmail.send';
  DCSOAuth2Authenticator.RedirectionEndpoint   := DCSOAuth2Authenticator.getLocalRedirectionURL_andSetPort;

  // Application specific options (created on Google's console)
  DCSOAuth2Authenticator.ClientID              := 'your ClientID goes here';      // ClientID created on console.developers.google.com
  DCSOAuth2Authenticator.ClientSecret          := 'your ClientSecret goes here';  // ClientSecret for the application registered on console.developers.google.com

  // Email hint
  DCSOAuth2Authenticator.LoginHint := senderEmail;
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.emailSender_send_viaGmail;
var
  restClient:   TRestClient;
  restRequest:  TRESTRequest;
  fromChanged:  boolean;
  endPoint:     string;
  fromEmail:    string;
  MSG_email:    TIdMessage;
  msgStream:    tMemoryStream;
  errJSON_Obj:  TJSonObject;
  errJSONValue: TJSonValue;
  errorStr:     string;
begin
  MSG_email   := self.getEmailMessage_fromForm;
  fromChanged := TSL_tokens.Values[EDT_email_google.Name] <> EDT_email_google.Text;
  fromEmail   := MSG_email.From.Address;
  msgStream   := tMemoryStream.Create;

  // IMPORTANT: sender email in the URL
  endPoint     := format('https://gmail.googleapis.com/upload/gmail/v1/users/%s/messages/send', [fromEmail]);

  restClient   := TRestClient.Create(endPoint);
  restRequest  := TRESTRequest.Create(restClient);

  errJSON_Obj  := TJSonObject.Create;
  errJSONValue := TJSonValue.Create;

  self.prepareAuthenticator(fromEmail, fromChanged);    // Clear tokens if From email changed
  restClient.Authenticator := DCSOAuth2Authenticator;

  try
    if MSG_email.BccList.Count <= 0
       then MSG_email.SaveToStream(msgStream, false)
       else begin
            MSG_email.SaveToFile  (privAppPath + 'tmp.eml');   // Limitation of Indy, when bcc is set TIdMessage.SaveToStream loses that field. We use TIdMessage.SaveToFile and then stream.LoadFromFile to get arround that problem
            msgStream.LoadFromFile(privAppPath + 'tmp.eml');
            end;

    // Add email headers
    restRequest.Method := TRESTRequestMethod.rmPOST;
    restRequest.Params.AddHeader('Content-Type',  htmlEncode('message/rfc822'));
    restRequest.Params.ParameterByName('Content-Type').Options  := [poDoNotEncode];
    restRequest.AddParameter('uploadType', 'media', pkQUERY);

    restRequest.Body.Add(msgStream, ctMESSAGE_RFC822);        // If email with metadata only, use: //restRequest.Body.Add(format('{"raw": "%s"}', [MEM_base64.Lines.Text]), ctMESSAGE_RFC822);

    //*************
    // Send request
    restRequest.Execute;

    if fromChanged then
       self.saveOptions;

    // If Error response
    if restRequest.Response.GetSimpleValue('error', errorStr) then       // Check if an error was returned
       begin
       errorStr     := 'Error sending Email (generic).';                 // Default error
       errJSONValue := errJSON_Obj.ParseJSONValue(restRequest.Response.Content, false, true);

       if errJSONValue <> nil then errJSONValue := (errJSONValue as TJSONObject).Get('error').JSONValue;
       if errJSONValue <> nil then errorStr     := (errJSONValue as TJSONObject).GetValue('message').Value;

       raise Exception.Create('Google: ' + errorStr);
       end;

  finally
    restClient.DisposeOf;
    msgStream.Free;
    errJSON_Obj.Free;
    errJSONValue.Free;
  end;
end;


{ ***** / /  *****  / /  ******  / / ***** }
function TFRM_sendMail.getEmailMessage_fromForm: tIdMessage;
var
  i:         integer;
  myIndyMsg: TIdMessage;
  textPart:  TIdText;
  htmlPart:  TIdText;
  htmlStr:   string;
begin
  myIndyMsg := TIdMessage.Create;

  //************
  // Message cfg
  myIndyMsg.clear;
  myIndyMsg.Encoding               := meMIME;
  myIndyMsg.BccList.EMailAddresses := EDT_toEmail.Text;
  myIndyMsg.from.Name              := 'Delphi Application';
  myIndyMsg.from.Address           := EDT_email_google.Text;
  myIndyMsg.CharSet                := 'UTF-8';
  myIndyMsg.Subject                := EDT_toSubject.Text;

  // Only 1 recipient, use To field instead of Bcc
  if myIndyMsg.BccList.Count = 1 then
     begin
     myIndyMsg.Recipients.Add.Assign(myIndyMsg.BccList.Items[0]);
     myIndyMsg.BccList.Delete(0);
     end;

  myIndyMsg.Body.Clear;
  myIndyMsg.ContentType := 'multipart/alternative';

  // Plain version
  textPart             := TIdText.Create(myIndyMsg.MessageParts);
  textPart.Body.Text   := MEM_toMessage.Lines.Text;
  textPart.ContentType := 'text/plain';
  textPart.CharSet     := 'UTF-8';
  textPart.ParentPart  := -1;

  // HTML version
  htmlStr := '';
  for i := 0 to MEM_toMessage.Lines.Count - 1 do
      htmlStr := htmlStr + MEM_toMessage.Lines[i] + '<br>';
  htmlStr := '<div style="font-family: Basier Circle,Helvetica Neue,Arial,sans-serif; font-weight: normal; font-size: 14px;">' + htmlStr + '</div>';

  htmlPart             := TIdText.Create(myIndyMsg.MessageParts);
  htmlPart.ContentType := 'text/html';
  htmlPart.CharSet     := 'UTF-8';
  htmlPart.ParentPart  := -1;
  htmlPart.Body.Text   := htmlStr;

  result := myIndyMsg;
end;

end.
