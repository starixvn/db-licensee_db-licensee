ALTER PROCEDURE [dbo].[Lrf_Rpt_DepositWithdrawal]
	@LicenseeID INT ,
	@CurrencyID INT,
	@FromDate		SMALLDATETIME,  
	@ToDate		SMALLDATETIME,   
	@username VARCHAR(50) = NULL,
	@SumDeposit MONEY = 0 OUTPUT,
	@SumWithdrawal MONEY = 0 OUTPUT,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT
AS
BEGIN
/*
NO MORE USE!!!

Created: 20120822@Henry
Task : Customer Deposit Withdrawal Report
DB: DB06.bodb02


Revisions:
	-20121004@Jim: replace @currency input param by @currencyID
Param's Explanation:

Example: 
EXEC [Lrf_Rpt_DepositWithdrawal] @LicenseeID=1,@CurrencyID=3,@FromDate='2012-08-01', @ToDate = '2012-08-22',@PageSize=1000

*/	
SET NOCOUNT ON  

DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
DECLARE @TempFromDate SMALLDATETIME, @TempToDate SMALLDATETIME 
DECLARE @tmpAg	TABLE( custID INT)  
DECLARE @CutDate DATETIME, @CustID INT
DECLARE @Today SMALLDATETIME, @Yesterday SMALLDATETIME
DECLARE @RowStart INT, @RowEnd INT 

SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
SET @Yesterday = CONVERT(VARCHAR(10), DATEADD(DAY,-1,@Today), 120) 

SELECT @_FromDate = @FromDate, @_ToDate = @ToDate

SELECT @CutDate =  min(winlostdate) from bodb_report.dbo.rptdepwinlost with(nolock) 
SET @username = LTRIM(RTRIM(ISNULL(@username,'')))

SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

--Get List of Agent
INSERT INTO @tmpAg
SELECT CustID FROM DB052.bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )
WHERE   
	LicenseeID = @LicenseeID
	AND (Currency = @CurrencyID)


--Get CustID when input Username
IF (@username = '')
	SET @CustID = 0
ELSE
BEGIN
	SELECT @CustID = CustID FROM Customer c WITH (NOLOCK)
	WHERE 
		SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) = @username
		AND recommend IN (SELECT custid FROM @tmpAg)
		AND roleid = 1
	
	IF ISNULL(@CustID,0)=0
	BEGIN
		SELECT @CustID = CustID FROM Customer WITH (NOLOCK)
		WHERE username = @username
	END
	
	IF ISNULL(@CustID,0) =0
		SET @CustID = -1

END		

CREATE TABLE #tmpRpt (
	CustID INT,
	Deposit MONEY,
	Withdrawal MONEY
	)	
	
IF @CustID <> -1 AND @_ToDate>=@_FromDate --In case no member found then do nothing
BEGIN
	IF @_FromDate >= @CutDate
		BEGIN
			IF @CutDate < @_FromDate
				SELECT @TempFromDate = @_FromDate
			ELSE
				SELECT @TempFromDate = @CutDate
				
			IF @_ToDate>= @Today
				SELECT @TempToDate = @Yesterday
			ELSE
				SELECT @TempToDate = @_ToDate
				
			INSERT INTO #tmpRpt 
			SELECT 
				CustID,
				SUM(Deposit),
				SUM(Withdrawal)
			FROM bodb_Report.dbo.rptDepWinlost b WITH (nolock)
			where  
				winlostdate BETWEEN @TempFromDate AND @TempToDate
				AND (@CustID=0 OR (@CustID<>0 AND b.custid = @Custid))
				AND b.Recommend IN ( SELECT custid FROM @tmpAg) 	
			GROUP BY CustID	
			
			--Get data from bettrans for today
			IF @_ToDate>= @Today
			BEGIN
				INSERT INTO #tmpRpt 
				SELECT
					CustID,
					SUM( CASE WHEN bettype = 22001 then winlost-actual_stake ELSE 0 END), --Deposit  
					-SUM(CASE WHEN bettype in (22002,22003) then winlost-actual_stake ELSE 0 END)--Withdrawal  
				FROM bettrans b with(rowlock)   
				WHERE 
					winlostdate =@Today
					AND (@CustID=0 OR (@CustID<>0 AND b.custid = @Custid))
					AND recommend IN ( SELECT custid FROM @tmpAg) 
				GROUP BY CustID	
			END	
		END
	
	IF @_FromDate < @CutDate
	BEGIN
		IF @_ToDate >= DATEADD(dd, -1, @CutDate) 
			SELECT @TempToDate = DATEADD(dd, -1, @CutDate) 
		ELSE
			SELECT @TempToDate = @_ToDate
			
			INSERT INTO #tmpRpt 
				SELECT 
					CustID,
					SUM(Deposit),
					SUM(Withdrawal)
				FROM bodb_Report.dbo.rptDepWinlost_bk b WITH (nolock, INDEX=IX_recommend)
				where  
					winlostdate BETWEEN @_FromDate AND @TempToDate
					AND (@CustID=0 OR (@CustID<>0 AND b.custid = @Custid))
					AND b.Recommend IN ( SELECT custid FROM @tmpAg) 
				GROUP BY CustID	
	END
END

--Remove member that does not Deposit or Withdrawal
DELETE FROM #tmpRpt
WHERE Deposit = 0 AND Withdrawal = 0

--Get the sum data
SELECT 
	@SumDeposit=SUM(ISNULL(Deposit,0)),
	@SumWithdrawal=SUM(ISNULL(Withdrawal,0))
FROM #tmpRpt b

--Get the detail data
SELECT A.*
FROM 
	(	
		SELECT	ROW_NUMBER () OVER (ORDER BY username) AS RowNum,
			d.CustID,
			SUM(ISNULL(d.Deposit,0)) as Deposit,
			SUM(ISNULL(d.Withdrawal,0)) as Withdrawal,
			c.username,  
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
		FROM
			#tmpRpt d INNER JOIN Customer c ON d.custid = c.custid
		GROUP BY d.CustID, c.username,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2))	
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #tmpRpt

END			

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_DepositWithdrawal] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_DepositWithdrawal] TO [vnteam] 