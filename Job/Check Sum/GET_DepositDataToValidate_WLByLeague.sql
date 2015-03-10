USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[GET_DepositDataToValidate_WLByLeague]    Script Date: 13/03/2014 9:21:58 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.GET_DepositDataToValidate_Betting    Script Date: 3/26/2013 4:34:06 PM ******/

ALTER PROCEDURE [dbo].[GET_DepositDataToValidate_WLByLeague] 
	@Date SMALLDATETIME		= NULL
	, @DrawFilter TINYINT	= 1

AS 

/*
Created: 20140312@Florent
Task : Get deposit data from table db052.bodb_Licenseereport.dbo.rptWinlostbyLeague

DB: bodb_Licensee
Original:

Revisions:	
	- 20150211@Florent: add Sporting Solution bettype
Param's Explanation:
    @DrawFilter, 1:Normal - 2:No Draws - 3:No Draws For Turnover Only
    
Examples:
*/
SET NOCOUNT ON

DECLARE @SbTurnover			MONEY
       , @SbCustomerWl		MONEY
       , @SbBetCount		MONEY
       , @RbTurnover		MONEY
       , @RbCustomerWl		MONEY
       , @RbBetCount		MONEY
       , @NgTurnover		MONEY
       , @NgCustomerWl		MONEY
       , @NgBetCount		MONEY
       , @BaTurnover		MONEY
       , @BaCustomerWl		MONEY
       , @BaBetCount		MONEY
       , @CsTurnover		MONEY
       , @CsCustomerWl		MONEY
       , @CsBetCount		MONEY

SELECT b.* 
INTO #DATA
FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague b WITH (NOLOCK)
    INNER JOIN bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON b.recommend=lc.CustID
	 --inner join (SELECT custid FROM f_DepSuper_1('All')) LC  ON a.srecommend = lc.custid
WHERE B.winlostdate = @Date
	  AND lc.Currency NOT IN (20,27,28)

-- Sportbook
SELECT @SbTurnover = SUM(CASE 
                    WHEN @DrawFilter IN (2, 3) THEN 
                        CASE WHEN b.statusID = 111 THEN 0 
							 WHEN b.statusID IN (114, 115) THEN 0.5 
						ELSE 1 END
                    ELSE 1
                END * b.stake)
    , @SbCustomerWl = SUM(b.winlost)
    , @SbBetCount=SUM(CASE 
						WHEN @DrawFilter = 2 AND b.statusID = 111 THEN 0 
						ELSE b.BetCount 
					 END)
FROM  #DATA B
WHERE ((b.bettype < 31) OR (b.bettype >= 121 AND b.bettype < 1000) 
						 OR (b.bettype >= 1301 AND b.bettype <= 1399))
    AND b.statusID IN (111, 112, 113, 114, 115)
	AND b.isBA=0

SELECT @SbTurnover = ISNULL (@SbTurnover, 0),
	   @SbCustomerWl = ISNULL (@SbCustomerWl, 0),
	   @SbBetCount = ISNULL (@SbBetCount, 0)

-- Racing
SELECT @RbTurnover = SUM(CASE 
							WHEN b.statusID IN (114,115) THEN 0.5 
							ELSE 1 
						 END * b.stake) 
    , @RbCustomerWl = SUM(b.winlost)
    , @RbBetCount = SUM(CASE 
						WHEN @DrawFilter = 2 AND b.statusID = 111 THEN 0 
						ELSE b.BetCount 
					 END)
FROM  #DATA b
WHERE b.bettype >= 31 AND b.bettype <= 33
      AND b.statusID IN (111, 112, 113, 114, 115)

SELECT @RbTurnover = ISNULL (@RbTurnover, 0),
	   @RbCustomerWl = ISNULL (@RbCustomerWl, 0),
	   @RbBetCount = ISNULL (@RbBetCount, 0)
        
-- Number Game
SELECT @NgTurnover=SUM(CASE 
						WHEN @DrawFilter IN (2, 3) AND b.statusID = 111 THEN 0 
						ELSE b.stake 
					   END)
    , @NgCustomerWl = SUM(b.winlost)
    , @NgBetCount = SUM(CASE 
						WHEN @DrawFilter = 2 AND b.statusID = 111 THEN 0 
						ELSE b.BetCount 
					 END)
FROM  #data b
WHERE b.bettype >= 81 AND b.bettype <= 120
    AND b.statusID IN (111, 112, 113, 114, 115)    

SELECT @NgTurnover = ISNULL (@NgTurnover, 0),
	   @NgCustomerWl = ISNULL (@NgCustomerWl, 0),
	   @NgBetCount = ISNULL (@NgBetCount, 0)
	   
-- Ba
SELECT @BaTurnover=SUM(CASE 
							WHEN @DrawFilter IN (2,3) THEN 
								CASE WHEN b.statusID = 111 THEN 0 
									 WHEN b.statusID IN (114,115) THEN 0.5 
								ELSE 1 END
							ELSE 1
							END * b.stake)
    , @BaCustomerWl = SUM(b.winlost) 
    , @BaBetCount = SUM(CASE 
						WHEN @DrawFilter=2 AND b.statusID = 111 THEN 0 
						ELSE b.BetCount 
					 END)
FROM  #data b
WHERE b.statusID IN (111, 112, 113, 114, 115)   
	AND isba=1

SELECT @BaTurnover = ISNULL (@BaTurnover, 0)
	   , @BaCustomerWl = ISNULL (@BaCustomerWl, 0)
	   , @BaBetCount = ISNULL (@BaBetCount, 0)
	   
-- Live Casino
SELECT @CsTurnover=SUM(CASE 
						WHEN @DrawFilter IN (2,3) AND b.statusID = 111 THEN 0 
						ELSE b.stake 
					   END)
    , @CsCustomerWl = SUM(b.winlost)
    , @CsBetCount = SUM(CASE 
						WHEN @DrawFilter = 2 AND b.statusID = 111 THEN 0 
						ELSE b.BetCount 
					 END) 
FROM  #data b
WHERE b.bettype >= 1101 AND b.bettype <= 1199
    AND b.statusID IN (111, 112, 113, 114, 115)    

SELECT @CsTurnover = ISNULL (@CsTurnover, 0)
	   , @CsCustomerWl = ISNULL (@CsCustomerWl, 0)
	   , @CsBetCount = ISNULL (@CsBetCount, 0)


-- Result
SELECT 1 AS Id, @SbTurnover AS Sb, @RbTurnover AS Rb, @NgTurnover AS Ng, @BaTurnover AS Ba, @CsTurnover AS Cs
UNION
SELECT 2, @SbCustomerWl, @RbCustomerWl, @NgCustomerWl, @BaCustomerWl, @CsCustomerWl
UNION
SELECT 3, @SbBetCount, @RbBetCount, @NgBetCount, @BaBetCount, @CsBetCount

DROP TABLE #data
SET NOCOUNT OFF

GO
GRANT EXECUTE ON [dbo].[GET_DepositDataToValidate_WLByLeague] TO [bodbLicenseeNet] 
GRANT VIEW DEFINITION ON [dbo].[GET_DepositDataToValidate_WLByLeague] TO [vnteam] 
GO