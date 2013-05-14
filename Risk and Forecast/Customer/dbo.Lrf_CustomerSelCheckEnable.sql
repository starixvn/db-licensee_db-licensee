set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE [dbo].[Lrf_CustomerSelCheckEnable]
 @username	nvarchar(50)=null
,@custid	INT = 0 
,@Langkey VARCHAR(20) = 'en-US'
,@ErrCode	INT = 0 OUTPUT
,@ErrMsg	nvarchar(200) ='' OUTPUT 	
AS
/*
Created: 20101210@Henry
Task: check enable of a customer
DB: DB052.bodb02
Original: [Acc_CustomerSelCheckEnable]

Revisions:
	-20130413@Jim: support multi language

*/
BEGIN
SET NOCOUNT ON
DECLARE @isEnable BIT

if @custid =0
begin
	SELECT @isEnable = isnull(enabled,0) from custinfo with (nolock)
	WHERE username =@username 
END 
ELSE if @username is null 
begin
	SELECT @isEnable = isnull(enabled,0) from custinfo with (nolock)
	WHERE custid = @custid 
END

if @isEnable = 0 or @@rowcount =0
begin
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'This account was disabled!'
								   ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](60020,@Langkey)
									END
		, @ErrCode = 600   
	RETURN
END
END 

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelCheckEnable] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelCheckEnable] TO [vnteam]
