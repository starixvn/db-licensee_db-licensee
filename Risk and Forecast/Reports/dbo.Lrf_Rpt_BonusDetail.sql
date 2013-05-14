ALTER PROC [dbo].[Lrf_Rpt_BonusDetail]  
	@CurrencyID INT=0,  
	@BonusCode nvarchar(50)='',  
	@BeginDate DATETIME,
	@EndDate DATETIME,
	@PageSize INT = 1000,  
    @PageIndex INT = 1,
	@TotalRows INT = 0 OUTPUT
AS

/*
Created: 20111121@Dave
Task : Licensee Bonus Report Detail
DB: DBDeposit.Deposit_DB


Revisions:
   
Param's Explanation:
*/	

BEGIN
SET NOCOUNT ON  

SET @BonusCode = LTRIM(RTRIM(@BonusCode))

DECLARE @RowStart INT, @RowEnd INT  

SELECT  @PageIndex = @PageIndex - 1 ,  
        @RowStart = @PageSize * @PageIndex + 1 ,  
        @RowEnd = @RowStart + @PageSize - 1  
        
CREATE TABLE #TempBonusReport  
(  
	RowNum INT PRIMARY KEY CLUSTERED,  
	UserSEQ INT,
	CustomerName NVARCHAR(30),  
	FirstName NVARCHAR(50),  
	LastName NVARCHAR(50),  
	SecurityCode NVARCHAR(200),
	State NVARCHAR(50),
	City NVARCHAR(50),
	Lastip VARCHAR(30),
	DepositAmount DECIMAL,
	BonusCode NVARCHAR(50),
	Bonus DECIMAL,
	CreateDate DATETIME
)

INSERT INTO #TempBonusReport
SELECT *
FROM
(
SELECT
		ROW_NUMBER() OVER ( ORDER BY gb.CreateDate DESC) AS RowNum,
		gb.UserSEQ,  
		dc.username AS 'CustomerName',  
		dc.firstname,  
		dc.lastname,  
		dc.securitycode,  
		dc.state,  
		dc.city,  
		LastLoginIP as 'Lastip',  
		gb.DepositAmount,
		p.BonusCode,
		gb.Bonus,
		gb.CreateDate  
FROM	Deposit_Promotion_GrantBonus gb WITH(NOLOCK)   
INNER JOIN Deposit_Promotion_Profile p  WITH(NOLOCK) ON gb.ProfileID=p.ProfileID  
INNER JOIN Deposit_Customer dc WITH(NOLOCK) ON dc.custid = gb.UserSEQ  
WHERE p.Disabled=0 AND
	  ((@CurrencyID = 0) OR (gb.UCurrencyID= @CurrencyID)) AND
	  ((@BonusCode = '') OR (p.BonusCode = @BonusCode)) AND
	  gb.CreateDate BETWEEN @BeginDate + ' 00:00:00' AND @EndDate +' 23:59:59'
)BonusReport
ORDER BY BonusReport.CreateDate DESC
	
SELECT @TotalRows=COUNT(RowNum)
FROM #TempBonusReport

SELECT * FROM #TempBonusReport WHERE RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #TempBonusReport
END

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_BonusDetail] TO [bodbLicenseeNet]