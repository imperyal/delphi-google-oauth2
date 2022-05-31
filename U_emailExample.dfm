object FRM_sendMail: TFRM_sendMail
  Left = 0
  Top = 0
  Caption = 'FRM_sendMail'
  ClientHeight = 291
  ClientWidth = 352
  Color = clBtnFace
  Constraints.MinHeight = 300
  Constraints.MinWidth = 360
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    352
    291)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 17
    Top = 27
    Width = 65
    Height = 13
    Alignment = taRightJustify
    Caption = 'Sender email:'
  end
  object Label2: TLabel
    Left = 88
    Top = 46
    Width = 240
    Height = 13
    Anchors = [akLeft, akTop, akRight]
    Caption = '(email that will use Google API to send email)'
    ExplicitWidth = 214
  end
  object Label3: TLabel
    Left = 14
    Top = 75
    Width = 68
    Height = 13
    Alignment = taRightJustify
    Caption = 'Send email to:'
  end
  object Label4: TLabel
    Left = 42
    Top = 102
    Width = 40
    Height = 13
    Alignment = taRightJustify
    Caption = 'Subject:'
  end
  object Label5: TLabel
    Left = 36
    Top = 126
    Width = 46
    Height = 13
    Alignment = taRightJustify
    Caption = 'Message:'
  end
  object EDT_email_google: TEdit
    Left = 88
    Top = 24
    Width = 243
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    Text = 'imperyal@gmail.com'
    ExplicitWidth = 217
  end
  object EDT_toEmail: TEdit
    Left = 88
    Top = 72
    Width = 243
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
    Text = 'tiago@dcs.pt'
    ExplicitWidth = 217
  end
  object EDT_toSubject: TEdit
    Left = 88
    Top = 99
    Width = 243
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 2
    Text = 'Email subject'
    ExplicitWidth = 217
  end
  object MEM_toMessage: TMemo
    Left = 88
    Top = 126
    Width = 243
    Height = 114
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'Email message.')
    TabOrder = 3
    ExplicitWidth = 217
    ExplicitHeight = 89
  end
  object BUT_send: TButton
    Left = 256
    Top = 246
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Send'
    TabOrder = 4
    OnClick = BUT_sendClick
    ExplicitLeft = 230
    ExplicitTop = 221
  end
end
