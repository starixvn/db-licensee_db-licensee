ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMaxPerMatch152_41]
	@custid INT,
	@MaxPerMatch MONEY,
	@Language VARCHAR(2) = 'E',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
Created: 20110330@Henry
Task : Update maxpermatch of a customer
DB: DBTRANS.bodb02

Revisions:
	
	
Param's Explanation:
• @ErrCode:
    = 0: Update successfully.
    > 0: Specific Error.
  
• @ErrMsg: Error description.
*/
	SET NOCOUNT ON
		

	update custinfo with (ROWLOCK, UPDLOCK)
	SET 	
		MaxPerMatch152_UK = @MaxPerMatch
	WHERE custid = @custid
	if (@@error <> 0)
	begin		
		SELECT @ErrMsg = CASE @Language 
							WHEN 'E' THEN 'Update process is unsuccessful !'
							WHEN 'CS' THEN N'更新程序不成功 !'
							WHEN 'CT' THEN N'更新程序不成功 !'
							WHEN 'TH' THEN N'ขั้นตอนหรือกระบวนการในการปรับยอดไม่เสร็จสิ้น.'
							WHEN 'J' THEN N'アップデート出来ません。'
							WHEN 'KO' THEN N'업데이트에 실패했습니다.'
							ELSE N'Update process is unsuccessful !'
						END, @ErrCode = 115
		RETURN
	END


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMaxPerMatch152_41] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdMaxPerMatch152_41] TO [vnteam]