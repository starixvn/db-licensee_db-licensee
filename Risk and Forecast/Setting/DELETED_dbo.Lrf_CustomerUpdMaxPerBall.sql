ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMaxPerBall]
	@custid INT,
	@maxperballv161 MONEY = 0,
	@Language VARCHAR(10) = 'en-us',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS

/*
Created: 20101216@Henry
Task : Update Maxperball
DB: DBTRANS.bodb02
Original: Acc_CustomerUpdMaxPerBall

Revisions:
    - 20110519@Henry: Remove @UpdateMultiple + @UpdateMinMaxBetv161
	- 20151023@Victor: Support New Simplified Chinese
Param's Explanation:

*/

update custinfo with (ROWLOCK, UPDLOCK)
SET 	
	MaxPerBall161 = @maxperballv161
WHERE custid = @custid 
if (@@error <> 0)
begin
	SELECT @ErrMsg = CASE @Language 
						WHEN 'en-us' THEN 'Update process is unsuccessful !'
						WHEN 'zh-cn' THEN N'更新程序不成功 !'
						WHEN 'zh-tw' THEN N'更新程序不成功 !'
						WHEN 'zh-Hans' THEN N'更新程序不成功 !'
						WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น.'
						WHEN 'Ja' THEN N'アップデート出来ません。'
						WHEN 'KO' THEN N'업데이트에 실패했습니다.'
						ELSE N'Update process is unsuccessful !'
					END, @ErrCode = 100
	RETURN
END

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMaxPerBall] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMaxPerBall] TO [vnteam] 