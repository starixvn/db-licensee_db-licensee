 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  FUNCTION [dbo].[Lrf_f_TranslateMsg]
(
	@Msg		VARCHAR(100),
	@Language	NVARCHAR(10)='en-US' 
)
RETURNS NVARCHAR(4000) 
AS
/*
	Created by: Jim
	Date: 2013-04-05
	Task: Get the content of message from msgID 
	DB: DBEXT/bodb02
	Original:DBTRANS.bodb02.f_Get_MsgNamebyMsgID
	Revisions: 
		+ 20151023@Victor: Support New Simplified Chinese 
	
*/
BEGIN
	-- Declare the return variable here
	DECLARE	@MsgName	NVARCHAR(4000)
	SELECT @Language=LTRIM(RTRIM(@Language))
	SELECT @Msg=LTRIM(RTRIM(@Msg))
	
	SELECT	@MsgName = CASE @Language
										WHEN 'zh-CN'	THEN MsgNameCS
										WHEN 'zh-TW'	THEN MsgNameCT
										WHEN 'th-TH'	THEN MsgNameTH
										WHEN 'ja-JP'	THEN MsgNameJP
										WHEN 'ko-KR'	THEN MsgNameKO
										WHEN 'es'  	    THEN MsgNameES
										WHEN 'vi-VN'	THEN MsgNameVI
										WHEN 'zh-Hans'	THEN MsgNameCN
										ELSE MsgNameEN END 
										
	FROM	dbo.MsgError WITH (NOLOCK)
	WHERE	MsgNameEN=@Msg
			AND IsActive=1		
	-- Return the result of the function
	RETURN	@MsgName

END
GO

GRANT VIEW DEFINITION ON [dbo].[Lrf_f_TranslateMsg] TO [vnteam]
Go
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_TranslateMsg] TO [bodbLicenseeNet]
Go
GRANT EXECUTE  ON [dbo].[Lrf_f_TranslateMsg] TO [bodbLicenseeNet]
