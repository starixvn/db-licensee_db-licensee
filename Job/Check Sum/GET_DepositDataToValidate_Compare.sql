USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[GET_DepositDataToValidate_Compare]    Script Date: 27/03/2014 2:22:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[GET_DepositDataToValidate_Compare] 
    @Date smalldatetime = null
	,@DrawFilter tinyint = 1
AS
/*
Created: 20140312@Florent
Task : Compare data from 4 table sum

DB: bodb_Licensee
Original:

Revisions:		
Param's Explanation:
    @DrawFilter, 1:Normal - 2:No Draws - 3:No Draws For Turnover Only

TypeID: table sum
	1 rptLicWinloss2 -- default
	2 rptCustomerTurnover
	3 rptCustomerMatch
	4 rptWinlossbyLeague
ID : 
	1 Turnover
	2 Customer Winlost
	3 Betcount    
Examples:


*/
SET NOCOUNT ON
DECLARE
	   @flag bit=0

	   ,@NumberTemp_SB BIGINT
	   ,@PivotNumb_SB BIGINT
	   ,@NumberTemp_RB BIGINT
	   ,@PivotNumb_RB BIGINT
	   ,@NumberTemp_NG BIGINT
	   ,@PivotNumb_NG BIGINT
	   ,@NumberTemp_BA BIGINT
	   ,@PivotNumb_BA BIGINT
	   ,@NumberTemp_CS BIGINT
	   ,@PivotNumb_CS BIGINT

	   ,@id INT=1
	   ,@mesg Nvarchar (MAx)=''

CREATE TABLE #TempData 
		(ID INT
	   ,Sportbook bigint
       ,Racing bigint
       ,NumberGame bigint
	   ,BA bigint
	   ,CS bigint
	   )

CREATE TABLE #Data 
		(Typeid iNT
		,ID INT
	   ,Sportbook bigint
       ,Racing bigint
       ,NumberGame bigint
	   ,BA bigint
	   ,CS bigint
	   )

--exec 
INSERT INTO #TempData
exec dbo.GET_DepositDataToValidate_LicenseeWL @Date=@Date
INSERT into #Data
SELECT 1,* from #TempData
DELETE  #tempdata

INSERT INTO #TempData
exec dbo.GET_DepositDataToValidate_CustomerTurnover @Date=@Date
INSERT into #Data
SELECT 2,* from #TempData
DELETE  #tempdata

INSERT INTO #TempData
exec dbo.GET_DepositDataToValidate_CustomerMatch @Date=@Date
INSERT into #Data
SELECT 3,* from #TempData
DELETE  #tempdata

INSERT INTO #TempData
exec dbo.GET_DepositDataToValidate_WLByLeague @Date=@Date
INSERT into #Data
SELECT 4,* from #TempData
DELETE  #tempdata

--compare Turnover
WHILE (@id<4)--1.turnover 2.CustWL 3.Betcount
BEGIN
	DECLARE @typeid int =1
	WHILE (@typeid<=4)--1.rptLicWinlost2 2.CustomerTurnover 3. CustomerMatch 4.WinlostByLeague
	BEGIN		
		DECLARE @mesg2 nvarchar(1000)=''
		IF @typeid=1 --each table
			SELECT  @PivotNumb_SB=Sportbook,
					@PivotNumb_RB=Racing,
					@PivotNumb_NG=NumberGame,
					@PivotNumb_CS=CS,
					@PivotNumb_BA=BA
			FROM #Data WHERE Typeid=@typeid and id=@id
		IF @typeid<>1 		
			BEGIN					
				SELECT  @NumberTemp_SB=Sportbook,
						@NumberTemp_RB=Racing,
						@NumberTemp_NG=NumberGame,
						@NumberTemp_CS=CS,
						@NumberTemp_BA=BA
				FROM #Data WHERE Typeid=@typeid and id=@id	
				IF (@PivotNumb_SB<>@NumberTemp_SB)--check SB
					BEGIN
						if ((@id= 2 and ABS(@NumberTemp_SB-@PivotNumb_SB)<=1) OR (@id<>2))
							begin 
								set @flag=1
								select @mesg2=@mesg2+'Diff : Sport Book, ID ['+Convert(nvarchar,@id,102)+'], Date '+Convert(nvarchar,@Date,102)+' '							
							end 
					END 
				IF (@PivotNumb_RB<>@NumberTemp_RB)--check RB
					BEGIN
						if ((@id= 2 and ABS(@NumberTemp_SB-@PivotNumb_SB)<=1) OR (@id<>2))
							begin 
								set @flag=1
								select @mesg2=@mesg2+'Diff : Racing Book, ID ['+Convert(nvarchar,@id,102)+'], Date '+Convert(nvarchar,@Date,102)+' '						
							end 
					END
				IF (@PivotNumb_NG<>@NumberTemp_NG)--check NG					
					BEGIN 
						if ((@id= 2 and ABS(@NumberTemp_SB-@PivotNumb_SB)<=1) OR (@id<>2))			
							begin 
								set @flag=1
								select @mesg2=@mesg2+'Diff : Number Game, ID ['+Convert(nvarchar,@id,102)+'], Date '+Convert(nvarchar,@Date,102)+' '							
							end 
					END
				IF (@PivotNumb_BA<>@NumberTemp_BA)--check BA					
					BEGIN 
						if ((@id= 2 and ABS(@NumberTemp_SB-@PivotNumb_SB)<=1) OR (@id<>2))
							begin 
								set @flag=1
								select @mesg2=@mesg2+'Diff : BA, ID ['+Convert(nvarchar,@id,102)+'], Date '+Convert(nvarchar,@Date,102)+' '													
							end 
					END
				IF (@PivotNumb_CS<>@NumberTemp_CS)--check Live Casino
					BEGIN 
						if ((@id= 2 and ABS(@NumberTemp_SB-@PivotNumb_SB)<=1) OR (@id<>2))
							begin 
								set @flag=1
								select @mesg2=@mesg2+'Diff : Live Casino, ID ['+Convert(nvarchar,@id,102)+'], Date '+Convert(nvarchar,@Date,102)+' '													
							END
					END
			END	
		IF @mesg2!=''
		SET @mesg=@mesg+@mesg2+';'	
		SET @typeid=@typeid+1
	END  
	SET @id=@id+1
END

 if (@flag=1)
	 BEGIN		 
		 RAISERROR (@mesg,16,1); 
	END 

DROP TABLE #Data
DROP TABLE #TempData 

SET NOCOUNT OFF


