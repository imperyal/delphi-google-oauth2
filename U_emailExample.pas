unit U_emailExample;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  U_DCS_OAuth2, IdBaseComponent, IdMessage;

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
    privAppPath: string;
    DCSOAuth2Authenticator: TDCSOAuth2Authenticator;

    procedure googleAPI_prepare(senderEmail: string; clearTokens: boolean = false);
    procedure emailSender_send_viaGmail;
    function  getEmailMessage_fromForm: tIdMessage;
  public
    { Public declarations }
  end;

var
  FRM_sendMail: TFRM_sendMail;

implementation

{$R *.dfm}

uses
  REST.Client, REST.Types, System.JSON, Web.HTTPApp, IdText;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.FormCreate(Sender: TObject);
begin
  privAppPath := Application.ExeName;
  privAppPath := ExtractFilePath(privAppPath);

  DCSOAuth2Authenticator := TDCSOAuth2Authenticator.Create(nil);
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.FormDestroy(Sender: TObject);
begin
  DCSOAuth2Authenticator.Free;
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.BUT_sendClick(Sender: TObject);
begin
  self.emailSender_send_viaGmail;
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.googleAPI_prepare(senderEmail: string; clearTokens: boolean = false);
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
  DCSOAuth2Authenticator.ClientID              := 'Enter your ClientID';      // ClientID created on console.developers.google.com
  DCSOAuth2Authenticator.ClientSecret          := 'Enter your ClientSecret';  // ClientSecret for the application registered on console.developers.google.com

  // Email hint
  DCSOAuth2Authenticator.LoginHint := senderEmail;
end;


{ ***** / /  *****  / /  ******  / / ***** }
procedure TFRM_sendMail.emailSender_send_viaGmail;
var
  restClient:   TRestClient;
  restRequest:  TRESTRequest;
  endPoint:     string;
  cliEmail:     string;
  MSG_email:    TIdMessage;
  msgStream:    tMemoryStream;
  errJSON_Obj:  TJSonObject;
  errJSONValue: TJSonValue;
  errorStr:     string;
begin
  MSG_email    := self.getEmailMessage_fromForm;
  cliEmail     := MSG_email.From.Address;
  endPoint     := format('https://gmail.googleapis.com/upload/gmail/v1/users/%s/messages/send', [cliEmail]);
  msgStream    := tMemoryStream.Create;
  restClient   := TRestClient.Create(endPoint);
  restRequest  := TRESTRequest.Create(restClient);
  errJSON_Obj  := TJSonObject.Create;
  errJSONValue := TJSonValue.Create;

  self.googleAPI_prepare(cliEmail, false);
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
  myIndyMsg.from.Name              := 'Delphi test Email';
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
