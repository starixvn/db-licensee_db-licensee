ALTER PROCEDURE [dbo].[Lrf_Statement_Rpt]
    @LicenseeID INT ,
    @CurrencyID INT=0 ,
    @LicenseeType VARCHAR(100) = NULL ,
    @fromdate DATETIME ,
    @todate DATETIME ,
    @BalanceUpDay DATETIME ,
    @PageSize INT = 50 ,
    @PageIndex INT = 1 
    

/*
Created: 20101208@Henry
Task : Statement Report of Agent
DB: DB052.bodb02
Original: Age_Statement_Rpt_Ag

Revisions:
   -- 20110304@Henry: suppport based currency
   -- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
   -- 20121004@Jim: replace @currencyname input param by @currencyID
   -- 20150130@Winnie: Add base currency GBP 
	No use anymore
Param's Explanation:

*/
AS 
    SET NOCOUNT ON
	
    DECLARE @TempAg AS TABLE ( custid INT )
    INSERT  INTO @TempAg
            ( custid
            )
            SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
                WHERE   LicenseeID = @LicenseeID  
                        AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
                        AND [Description] = COALESCE(@LicenseeType,  
                                                     [Description])

    DECLARE @RowStart INT ,
        @RowEnd INT 
        
    SELECT  @PageIndex = @PageIndex - 1 ,
            @RowStart = @PageSize * @PageIndex + 1 ,
            @RowEnd = @RowStart + @PageSize - 1

    DECLARE @StatementTable TABLE
        (
          accdate DATETIME ,
          transtype NVARCHAR(100) ,
          transdesc NVARCHAR(300) ,
          totalamt MONEY ,
          totalamtUSD MONEY ,
          totalamtEUR MONEY,
		  totalamtGBP MONEY
        )

    DECLARE @TempTable TABLE
        (
          custid INT ,
          accdate DATETIME ,
          transtype NVARCHAR(100) ,
          transdesc NVARCHAR(300) ,
          totalamt MONEY
        )

   

    IF @todate >= @BalanceUpDay 
        BEGIN
            IF @FromDate > @BalanceUpDay 
                SELECT  @FromDate = @BalanceUpDay 
	
            --INSERT  INTO @StatementTable
            INSERT  INTO @TempTable
                    SELECT  custid ,
                            transdate AS accdate ,
                            CASE typenamee
                              WHEN 'POS' THEN 'NET'
                              ELSE typenamee
                            END AS transtype ,
                            CASE typenamee
                              WHEN 'POS' THEN 'Net Revenue'
                              ELSE transdesc
                            END AS transdesc ,
                            SUM(winlost - actual_stake) AS totalamt
                    FROM    bettrans WITH ( NOLOCK )
                            INNER JOIN bettype WITH ( NOLOCK ) ON bettype.typeid = bettrans.bettype
                    WHERE   bettype >= 20000
                            AND winlostdate BETWEEN @fromdate AND @todate
                            AND custid IN ( SELECT  custid
                                            FROM    @TempAg )
                    GROUP BY custid ,
                            typenamee ,
                            transdesc ,
                            transdate ,
                            transid
                    UNION ALL
                    SELECT  recommend ,
                            winlostdate AS accdate ,
                            'NET' AS transtype ,
                            'Net Revenue' AS transdesc ,
                            SUM(awinlost) AS totalamt
                    FROM    bettrans WITH ( NOLOCK )
                    WHERE   bettype <= 19999
                            AND recommend IN ( SELECT   custid
                                               FROM     @TempAg )
                            AND winlostdate BETWEEN @fromdate AND @todate
                    GROUP BY winlostdate ,
                            recommend
                    HAVING  SUM(awinlost) <> 0
                    UNION ALL
                    SELECT  recommend ,
                            winlostdate AS accdate ,
                            'COM' AS transtype ,
                            'Commission' AS transdesc ,
                            SUM(comm - playercomm) AS totalamt
                    FROM    bettrans WITH ( NOLOCK )
                    WHERE   bettype <= 19999
                            AND recommend IN ( SELECT   custid
                                               FROM     @TempAg )
                            AND winlostdate BETWEEN @fromdate AND @todate
                    GROUP BY winlostdate ,
                            recommend
                    HAVING  SUM(comm - playercomm) <> 0

        END

    IF @fromdate < @BalanceUpDay 
        BEGIN	
            DECLARE @PreBalanceUpDay DATETIME
            IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay) 
                SELECT  @ToDate = DATEADD(dd, -1, @BalanceUpDay) + ' 23:59:59'
		
            SELECT TOP 1
                    @PreBalanceUpDay = accdate
            FROM    DB06.bodb_Report.dbo.Statement WITH ( NOLOCK )
            WHERE   custid IN ( SELECT  custid
                                FROM    @TempAg )
                    AND transdesc = 'OPENING BALANCE'
                    AND accdate <= @fromdate
            ORDER BY accdate DESC
	
            SELECT  @FromDate = ISNULL(@PreBalanceUpDay, @FromDate)	
	
            --INSERT  INTO @StatementTable
            INSERT  INTO @TempTable
                    SELECT  custid ,
                            accdate ,
                            CASE transtype
                              WHEN 'POS' THEN 'NET'
                              ELSE transtype
                            END AS transtype ,
                            CASE transtype
                              WHEN 'POS' THEN 'Net Revenue'
                              ELSE transdesc
                            END AS transdesc ,
                            totalamt
                    FROM    DB06.bodb_Report.dbo.Statement WITH ( NOLOCK )
                    WHERE   custid IN ( SELECT  custid
                                        FROM    @TempAg )
                            AND accdate BETWEEN @fromdate AND @todate
	
        END

    INSERT  INTO @StatementTable
            ( accdate ,
              transtype ,
              transdesc ,
              totalamt ,
              totalamtUSD ,
              totalamtEUR,
			  totalamtGBP
            )
            SELECT  b.accdate ,
                    b.transtype ,
                    b.transdesc ,
                    SUM(totalamt) totalamt ,
                    SUM(totalamt * e.USD) totalamtUSD ,
                    SUM(totalamt * e.EUR) totalamtEUR,
					SUM(totalamt * e.GBP) totalamtGBP
            FROM    @TempTable b
                    INNER JOIN custinfo c ( NOLOCK ) ON b.custid = c.custid
                    INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate))e 
                    ON e.exchangedate = CONVERT(VARCHAR(10), b.accdate, 120)
                                                             AND e.exchangeid = c.currency
            GROUP BY b.accdate ,
                    b.transtype ,
                    b.transdesc
		

    DECLARE @SumOfTotalAmt MONEY
    DECLARE @SumOfTotalAmtUSD MONEY
    DECLARE @SumOfTotalAmtEUR MONEY
	DECLARE @SumOfTotalAmtGBP MONEY
    SET @SumOfTotalAmt = 0
	SET @SumOfTotalAmtUSD = 0
	SET @SumOfTotalAmtEUR = 0
	SET @SumOfTotalAmtGBP = 0
	
	DECLARE @TempAmt MONEY
    DECLARE @TempAmtUSD MONEY
    DECLARE @TempAmtEUR MONEY
	DECLARE @TempAmtGBP MONEY

    IF ( ( @PageSize <= 0 )
         AND ( @PageIndex <= 0 )
       ) 
        BEGIN
            SELECT  * ,
                    ROW_NUMBER() OVER ( ORDER BY accdate, CASE
                                                              WHEN transdesc LIKE '%opening balance%'
                                                              THEN 1
                                                              ELSE CASE
                                                              WHEN transdesc LIKE '%Position%'
                                                              THEN 2
                                                              ELSE 3
                                                              END
                                                          END, transdesc ) AS RowNum
            FROM    @StatementTable
	
            RETURN
        END
    ELSE
    BEGIN
		SELECT  A.*
		FROM    ( SELECT    * ,
							ROW_NUMBER() OVER ( ORDER BY accdate, CASE
																  WHEN transdesc LIKE '%opening balance%'
																  THEN 1
																  ELSE CASE
																  WHEN transdesc LIKE '%Position%'
																  THEN 2
																  ELSE 3
																  END
																  END, transdesc ) AS RowNum
				  FROM      @StatementTable
				) A
		WHERE   A.RowNum BETWEEN @RowStart AND @RowEnd
		
		SELECT @SumOfTotalAmt = sum(A.totalamt),@SumOfTotalAmtUSD=sum(A.totalamtUSD),@SumOfTotalAmtEUR=sum(A.totalamtEUR),@SumOfTotalAmtGBP=sum(A.totalamtGBP)
		FROM
		(
			SELECT 
				*,
				ROW_NUMBER() over (order by accdate)  as RowNum	
			FROM @StatementTable
		) A
		WHERE A.RowNum < @RowStart AND A.transdesc not like '%opening balance%'
		
		SELECT TOP 1 @TempAmt = totalamt, @TempAmtUSD=totalamtUSD,@TempAmtEUR=totalamtEUR,@TempAmtGBP=totalamtGBP
		From @StatementTable
		WHERE transdesc like '%opening balance%'
		Order by accdate
		
		SET @SumOfTotalAmt = @SumOfTotalAmt + ISNULL(@TempAmt,0)
		SET @SumOfTotalAmtUSD = @SumOfTotalAmtUSD + ISNULL(@TempAmtUSD,0)
		SET @SumOfTotalAmtEUR = @SumOfTotalAmtEUR + ISNULL(@TempAmtEUR,0)
		SET @SumOfTotalAmtGBP = @SumOfTotalAmtGBP + ISNULL(@TempAmtGBP,0)
    END
    

    SELECT  
		COUNT(accdate) AS TotalRows,
		@SumOfTotalAmt as SumOfTotalAmt,
		@SumOfTotalAmtUSD as SumOfTotalAmtUSD,
		@SumOfTotalAmtEUR as SumOfTotalAmtEUR,
		@SumOfTotalAmtGBP as SumOfTotalAmtGBP
    FROM    @StatementTable
    


GO
GRANT  EXECUTE  ON [dbo].[Lrf_Statement_Rpt]  TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Statement_Rpt] TO [VNTeam]
GO




