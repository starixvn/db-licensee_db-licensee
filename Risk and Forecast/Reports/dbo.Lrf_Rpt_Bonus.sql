ALTER PROCEDURE [dbo].[Lrf_Rpt_Bonus]
	@CurrencyID INT=0,
	@BonusCode NVARCHAR(50)='',
	@BeginDate DATETIME,
	@EndDate DATETIME
AS
BEGIN

/*
Created: 20111121@Dave
Task : Licensee Bonus Report
DB: DBDeposit.Deposit_DB


Revisions:
   
Param's Explanation:
*/	
	SET NOCOUNT ON  
	SET @BonusCode = LTRIM(RTRIM(@BonusCode))

	SELECT	gb.UCurrencyID		AS CurrencyID,
			COUNT(gb.UserSEQ)	AS BonusCount,
			SUM(gb.Bonus)		AS Bonus
	FROM	Deposit_Promotion_GrantBonus gb WITH(NOLOCK) INNER JOIN 
			Deposit_Promotion_Profile	 p  WITH(NOLOCK) 
			ON gb.ProfileID = p.ProfileID
	WHERE	p.Disabled = 0 AND
			((@CurrencyID = 0) OR (gb.UCurrencyID = @CurrencyID)) AND
			((@BonusCode = '') OR (p.BonusCode = @BonusCode)) AND
			gb.CreateDate BETWEEN @BeginDate + ' 00:00:00' AND @EndDate + ' 23:59:59'
	GROUP BY gb.UCurrencyID 
	ORDER BY gb.UCurrencyID

END			

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_Bonus] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_Bonus] TO [vnteam] 