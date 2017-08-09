/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberBA_PositionTaking]  
 @custid INT,--memberid    
    
 @apositiontaking_1 SMALLMONEY,  
 @apositiontaking_2 SMALLMONEY,  
 @apositiontaking_3 SMALLMONEY,  
 @apositiontaking_4 SMALLMONEY,  
 @apositiontaking_5 SMALLMONEY,  
 @apositiontaking_6 SMALLMONEY,  
 @apositiontaking_7 SMALLMONEY,  
 @apositiontaking_8 SMALLMONEY,  
 @apositiontaking_9 SMALLMONEY,  
 @apositiontaking_10 SMALLMONEY,  
   
 @alivepositiontaking_1 SMALLMONEY,  
 @alivepositiontaking_3 SMALLMONEY,  
 @alivepositiontaking_7 SMALLMONEY,  
 @alivepositiontaking_8 SMALLMONEY,  
   
 @v2apositiontaking_1 SMALLMONEY,  
 @v2apositiontaking_2 SMALLMONEY,  
 @v2apositiontaking_3 SMALLMONEY,  
 @v2apositiontaking_7 SMALLMONEY,  
 @v2apositiontaking_8 SMALLMONEY,  
 @v2apositiontaking_20 SMALLMONEY,  
   
 @v3apositiontaking_1 SMALLMONEY,  
 @v3apositiontaking_2 SMALLMONEY,  
 @v3apositiontaking_3 SMALLMONEY,  
 @v3apositiontaking_20 SMALLMONEY,  
  
 @v5apositiontaking_1 SMALLMONEY,  
 @v5apositiontaking_2 SMALLMONEY,  
 @v5apositiontaking_3 SMALLMONEY,  
 @v5apositiontaking_20 SMALLMONEY,  
  
 @v8apositiontaking_1 SMALLMONEY,  
 @v8apositiontaking_3 SMALLMONEY,  
 @v8apositiontaking_20 SMALLMONEY,  
  
 @v10apositiontaking_1 SMALLMONEY,  
 @v10apositiontaking_2 SMALLMONEY,  
 @v10apositiontaking_3 SMALLMONEY,  
 @v10apositiontaking_20 SMALLMONEY,  
  
 @v11apositiontaking_1 SMALLMONEY,  
 @v11apositiontaking_20 SMALLMONEY,  
  
 @v99apositiontaking_1 SMALLMONEY,  
 @v99apositiontaking_2 SMALLMONEY,  
 @v99apositiontaking_3 SMALLMONEY,  
 @v99apositiontaking_9 SMALLMONEY,  
 @v99apositiontaking_20 SMALLMONEY,  
  
 @v154apositiontaking_20 SMALLMONEY,  
 @v44apositiontaking_3  SMALLMONEY,
 @UserID INT,   
 @IsAdmin BIT = 0,  
 @IP VARCHAR(40)='',   
 @Language VARCHAR(2)= 'E',   
 @ErrCode INT = 0 OUTPUT,  
 @ErrMsg nvarchar(4000) = '' OUTPUT  
AS  
/*  
Created: 20110608@Henry  
Task : Update Member's Position Taking, used WHEN Update Bet Aggregator ON/OFF for member  
DB: DBTXN.CustDB  
Original: [Acc_CustomerUpdMember_PositionTaking]  
  
Revisions:  
 - 20110728@Henry: Add new bettypes: Warrior, NextCombo, Number Group + remove Over/Under Dead Ball  
 - 20110826@Henry: Remove PT of Number Game  
 - 20110907@Henry: Allow Acc-site to update PT (When disable BA of a licensee --> turn back BA member to normal)  
 - 20120718@Dom.Cao: Change table custsetting to dep_custsetting and custsetting3rd to dep_custsetting3rd   
 - 20131113@winnie: Add bodb02.dbo  
 - 20140425@Francis: Add HR Fixed Odds  
 - 20150610@Joseph: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB, use temp table for GameType table)
 - 20151015@Jim: Integrate Sportbook2 (Feature #44759)
 - 20170809@Winnie: Change Data Type of Sporttype [RedmineID: #73545]
Param's Explanation:  
• @ErrCode:  
    = 0: Update successfully.  
    > 0: Specific Error.  
    
• @ErrMsg: Error description.  
*/  
  
SET NOCOUNT ON  
  
DECLARE @tmp_Sports TABLE (SportType SMALLINT, SportName NVARCHAR(50))
DECLARE @tmp_Bettype TABLE (TypeID INT, TypeNamee NVARCHAR(50))

BEGIN TRY
	INSERT INTO @tmp_Sports (SportType, SportName)
	SELECT SportType, SportName FROM DBAGE.bodb02.dbo.Sports WITH (NOLOCK)		
END TRY
BEGIN CATCH
	INSERT INTO @tmp_Sports (SportType, SportName)
	SELECT SportType, SportName FROM DBTXN.bodb02.dbo.Sports WITH (NOLOCK)	
END CATCH

BEGIN TRY			
	INSERT INTO @tmp_Bettype (TypeID, TypeNamee)
	SELECT TypeID, TypeNamee FROM DBAGE.bodb02.dbo.Bettype WITH (NOLOCK)
END TRY
BEGIN CATCH		
	INSERT INTO @tmp_Bettype (TypeID, TypeNamee)
	SELECT TypeID, TypeNamee FROM DBTXN.bodb02.dbo.Bettype WITH (NOLOCK)
END CATCH

DECLARE @startRun DATETIME  
DECLARE @endRun DATETIME  
DECLARE @duration INT  
SET @startRun = GETDATE()   

DECLARE    
 @Recommend INT,   
 @MRecommend INT,  
 @UserName VARCHAR(40),  
 @ErrAcc VARCHAR(4000), @ErrType VARCHAR(4000),  
 --m1  
 @mpositiontaking_1 SMALLMONEY,  
 @mpositiontaking_2 SMALLMONEY,  
 @mpositiontaking_3 SMALLMONEY,  
 @mpositiontaking_4 SMALLMONEY,  
 @mpositiontaking_5 SMALLMONEY,  
 @mpositiontaking_6 SMALLMONEY,  
 @mpositiontaking_7 SMALLMONEY,  
 @mpositiontaking_8 SMALLMONEY,  
 @mpositiontaking_9 SMALLMONEY,  
 @mpositiontaking_10 SMALLMONEY,  
   
 @mlivepositiontaking_1 SMALLMONEY,  
 @mlivepositiontaking_3 SMALLMONEY,  
 @mlivepositiontaking_7 SMALLMONEY,  
 @mlivepositiontaking_8 SMALLMONEY,  
   
 @v2mpositiontaking_1 SMALLMONEY,  
 @v2mpositiontaking_2 SMALLMONEY,  
 @v2mpositiontaking_3 SMALLMONEY,  
 @v2mpositiontaking_7 SMALLMONEY,  
 @v2mpositiontaking_8 SMALLMONEY,  
 @v2mpositiontaking_20 SMALLMONEY,  
  
 @v3mpositiontaking_1 SMALLMONEY,  
 @v3mpositiontaking_2 SMALLMONEY,  
 @v3mpositiontaking_3 SMALLMONEY,  
 @v3mpositiontaking_20 SMALLMONEY,  
  
 @v5mpositiontaking_1 SMALLMONEY,  
 @v5mpositiontaking_2 SMALLMONEY,  
 @v5mpositiontaking_3 SMALLMONEY,  
 @v5mpositiontaking_20 SMALLMONEY,  
  
 @v8mpositiontaking_1 SMALLMONEY,  
 @v8mpositiontaking_3 SMALLMONEY,  
 @v8mpositiontaking_20 SMALLMONEY,  
  
 @v10mpositiontaking_1 SMALLMONEY,  
 @v10mpositiontaking_2 SMALLMONEY,  
 @v10mpositiontaking_3 SMALLMONEY,  
 @v10mpositiontaking_20 SMALLMONEY,  
  
 @v11mpositiontaking_1 SMALLMONEY,  
 @v11mpositiontaking_20 SMALLMONEY,  
  
 @v99mpositiontaking_1 SMALLMONEY,  
 @v99mpositiontaking_2 SMALLMONEY,  
 @v99mpositiontaking_3 SMALLMONEY,  
 @v99mpositiontaking_9 SMALLMONEY,  
 @v99mpositiontaking_20 SMALLMONEY,  
  
 @v154mpositiontaking_20 SMALLMONEY,  
 @v44mpositiontaking_3 SMALLMONEY,  
 --m3  
 @mapositiontaking_1_max SMALLMONEY,  
 @mapositiontaking_2_max SMALLMONEY,  
 @mapositiontaking_3_max SMALLMONEY,  
 @mapositiontaking_4_max SMALLMONEY,  
 @mapositiontaking_5_max SMALLMONEY,  
 @mapositiontaking_6_max SMALLMONEY,  
 @mapositiontaking_7_max SMALLMONEY,  
 @mapositiontaking_8_max SMALLMONEY,  
 @mapositiontaking_9_max SMALLMONEY,  
 @mapositiontaking_10_max SMALLMONEY,  
   
 @malivepositiontaking_1_max SMALLMONEY,  
 @malivepositiontaking_3_max SMALLMONEY,  
 @malivepositiontaking_7_max SMALLMONEY,  
 @malivepositiontaking_8_max SMALLMONEY,  
   
 @v2mapositiontaking_1_max SMALLMONEY,  
 @v2mapositiontaking_2_max SMALLMONEY,  
 @v2mapositiontaking_3_max SMALLMONEY,  
 @v2mapositiontaking_7_max SMALLMONEY,  
 @v2mapositiontaking_8_max SMALLMONEY,  
 @v2mapositiontaking_20_max SMALLMONEY,  
   
 @v3mapositiontaking_1_max SMALLMONEY,  
 @v3mapositiontaking_2_max SMALLMONEY,  
 @v3mapositiontaking_3_max SMALLMONEY,  
 @v3mapositiontaking_20_max SMALLMONEY,  
  
 @v5mapositiontaking_1_max SMALLMONEY,  
 @v5mapositiontaking_2_max SMALLMONEY,  
 @v5mapositiontaking_3_max SMALLMONEY,  
 @v5mapositiontaking_20_max SMALLMONEY,  
  
 @v8mapositiontaking_1_max SMALLMONEY,  
 @v8mapositiontaking_3_max SMALLMONEY,  
 @v8mapositiontaking_20_max SMALLMONEY,  
  
 @v10mapositiontaking_1_max SMALLMONEY,  
 @v10mapositiontaking_2_max SMALLMONEY,  
 @v10mapositiontaking_3_max SMALLMONEY,  
 @v10mapositiontaking_20_max SMALLMONEY,  
  
 @v11mapositiontaking_1_max SMALLMONEY,  
 @v11mapositiontaking_20_max SMALLMONEY,  
  
 @v99mapositiontaking_1_max SMALLMONEY,  
 @v99mapositiontaking_2_max SMALLMONEY,  
 @v99mapositiontaking_3_max SMALLMONEY,  
 @v99mapositiontaking_9_max SMALLMONEY,   
 @v99mapositiontaking_20_max SMALLMONEY,   
   
 @v154mapositiontaking_20_max SMALLMONEY,  
  @v44mapositiontaking_3_max SMALLMONEY,
 --old_a1  
 @old_apositiontaking_1 SMALLMONEY,  
 @old_apositiontaking_2 SMALLMONEY,  
 @old_apositiontaking_3 SMALLMONEY,  
 @old_apositiontaking_4 SMALLMONEY,  
 @old_apositiontaking_5 SMALLMONEY,  
 @old_apositiontaking_6 SMALLMONEY,  
 @old_apositiontaking_7 SMALLMONEY,  
 @old_apositiontaking_8 SMALLMONEY,  
 @old_apositiontaking_9 SMALLMONEY,  
 @old_apositiontaking_10 SMALLMONEY,  
   
 @old_alivepositiontaking_1 SMALLMONEY,  
 @old_alivepositiontaking_3 SMALLMONEY,  
 @old_alivepositiontaking_7 SMALLMONEY,  
 @old_alivepositiontaking_8 SMALLMONEY,  
   
 @old_v2apositiontaking_1 SMALLMONEY,  
 @old_v2apositiontaking_2 SMALLMONEY,  
 @old_v2apositiontaking_3 SMALLMONEY,  
 @old_v2apositiontaking_7 SMALLMONEY,  
 @old_v2apositiontaking_8 SMALLMONEY,  
 @old_v2apositiontaking_20 SMALLMONEY,  
  
 @old_v3apositiontaking_1 SMALLMONEY,  
 @old_v3apositiontaking_2 SMALLMONEY,  
 @old_v3apositiontaking_3 SMALLMONEY,  
 @old_v3apositiontaking_20 SMALLMONEY,  
  
 @old_v5apositiontaking_1 SMALLMONEY,  
 @old_v5apositiontaking_2 SMALLMONEY,  
 @old_v5apositiontaking_3 SMALLMONEY,  
 @old_v5apositiontaking_20 SMALLMONEY,  
  
 @old_v8apositiontaking_1 SMALLMONEY,  
 @old_v8apositiontaking_3 SMALLMONEY,  
 @old_v8apositiontaking_20 SMALLMONEY,  
  
 @old_v10apositiontaking_1 SMALLMONEY,  
 @old_v10apositiontaking_2 SMALLMONEY,  
 @old_v10apositiontaking_3 SMALLMONEY,  
 @old_v10apositiontaking_20 SMALLMONEY,  
  
 @old_v11apositiontaking_1 SMALLMONEY,  
 @old_v11apositiontaking_20 SMALLMONEY,  
  
 @old_v99apositiontaking_1 SMALLMONEY,  
 @old_v99apositiontaking_2 SMALLMONEY,  
 @old_v99apositiontaking_3 SMALLMONEY,  
 @old_v99apositiontaking_9 SMALLMONEY,   
 @old_v99apositiontaking_20 SMALLMONEY,  
   
 @old_v154apositiontaking_20 SMALLMONEY ,
 @old_v44apositiontaking_3 SMALLMONEY 
   
  
SELECT    
 @Recommend = recommend,  
 @MRecommend = mrecommend,  
 @UserName = username  
FROM   
 custinfo WITH (NOLOCK)  
WHERE   
 CustID = @CustID  
  
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---Soccer
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  
if   
 @apositiontaking_1  <0  
 OR @apositiontaking_2  <0  
 OR @apositiontaking_3  <0  
 OR @apositiontaking_4  <0  
 OR @apositiontaking_5  <0  
 OR @apositiontaking_6  <0  
 OR @apositiontaking_7  <0  
 OR @apositiontaking_8  <0  
 OR @apositiontaking_9  <0  
 OR @alivepositiontaking_1  <0  
 OR @alivepositiontaking_3  <0  
 OR @alivepositiontaking_7  <0  
 OR @alivepositiontaking_8  <0    
 OR @apositiontaking_10 <0  
 OR @apositiontaking_1  >0.9  
 OR @apositiontaking_2  >0.9  
 OR @apositiontaking_3  >0.9  
 OR @apositiontaking_4  >0.9  
 OR @apositiontaking_5  >0.9  
 OR @apositiontaking_6  >0.9  
 OR @apositiontaking_7  >0.9  
 OR @apositiontaking_8  >0.9  
 OR @apositiontaking_9  >0.9  
 OR @apositiontaking_10 >0.9  
 OR @alivepositiontaking_1  >0.9  
 OR @alivepositiontaking_3  >0.9  
 OR @alivepositiontaking_7  >0.9  
 OR @alivepositiontaking_8  >0.9    
   
BEGIN  
 SELECT @ErrCode = 5  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Soccer).'  
      WHEN 'CS' THEN N'占成数不正确(于足球).'  
      WHEN 'CT' THEN N'佔成數不正確(於足球).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬาฟุตบอล).'  
      WHEN 'J' THEN N'Wrong position taking (for Soccer).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (축구).'  
      ELSE N'Wrong position taking (for Soccer).'  
    END  
 RETURN  
END  

--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
    SELECT 1 AS bettype, 1 AS sporttype, @apositiontaking_1 AS apositiontaking, @alivepositiontaking_1 AS alivepositiontaking  
  UNION ALL  SELECT 3 AS bettype, 1 AS sporttype, @apositiontaking_3 AS apositiontaking, @alivepositiontaking_3 AS alivepositiontaking  
  UNION ALL  SELECT 7 AS bettype, 1 AS sporttype, @apositiontaking_7 AS apositiontaking, @alivepositiontaking_7 AS alivepositiontaking  
  UNION ALL  SELECT 8 AS bettype, 1 AS sporttype, @apositiontaking_8 AS apositiontaking, @alivepositiontaking_8 AS alivepositiontaking  
  UNION ALL  SELECT 2 AS bettype, 1 AS sporttype, @apositiontaking_2 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 4 AS bettype, 1 AS sporttype, @apositiontaking_4 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 5 AS bettype, 1 AS sporttype, @apositiontaking_5 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 6 AS bettype, 1 AS sporttype, @apositiontaking_6 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 9 AS bettype, 1 AS sporttype, @apositiontaking_9 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 10 AS bettype, 1 AS sporttype, @apositiontaking_10 AS apositiontaking, 0 AS alivepositiontaking  
  ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 7  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
   
  
  
--Basketball  
if   
 @v2apositiontaking_1  <0  
 OR @v2apositiontaking_2  <0  
 OR @v2apositiontaking_3  <0  
 OR @v2apositiontaking_7  <0  
 OR @v2apositiontaking_8  <0  
 OR @v2apositiontaking_20  <0    
  
 OR @v2apositiontaking_1  >0.9  
 OR @v2apositiontaking_2  >0.9  
 OR @v2apositiontaking_3  >0.9  
 OR @v2apositiontaking_7  >0.9  
 OR @v2apositiontaking_8  >0.9  
 OR @v2apositiontaking_20  >0.9  
  
BEGIN  
 SELECT @ErrCode = 8  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Basketball).'  
      WHEN 'CS' THEN N'占成数不正确(于篮球).'  
      WHEN 'CT' THEN N'佔成數不正確(於籃球).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬาบาสเก็ตบอล).'  
      WHEN 'J' THEN N'Wrong position taking (for Basketball).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (농구).'  
      ELSE N'Wrong position taking (for Basketball).'  
    END  
 RETURN  
END  
  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 1 AS bettype, 2 AS sporttype, @v2apositiontaking_1 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 2 AS bettype, 2 AS sporttype, @v2apositiontaking_2 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 3 AS bettype, 2 AS sporttype, @v2apositiontaking_3 AS apositiontaking, 0 AS alivepositiontaking  
--   UNION ALL  SELECT 7 AS bettype, 2 AS sporttype, @v2apositiontaking_7 AS apositiontaking, 0 AS alivepositiontaking  
--   UNION ALL  SELECT 8 AS bettype, 2 AS sporttype, @v2apositiontaking_8 AS apositiontaking, 0 AS alivepositiontaking  
--   UNION ALL  SELECT 9 AS bettype, 2 AS sporttype, @v2apositiontaking_9 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 20 AS bettype, 2 AS sporttype, @v2apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 10  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
  
  
  
--Football  
  
if   
 @v3apositiontaking_1  <0  
 OR @v3apositiontaking_2  <0  
 OR @v3apositiontaking_3  <0  
 OR @v3apositiontaking_20  <0    
 OR @v3apositiontaking_1  >0.9  
 OR @v3apositiontaking_2  >0.9  
 OR @v3apositiontaking_3  >0.9  
 OR @v3apositiontaking_20  >0.9  
   
BEGIN  
 SELECT @ErrCode = 11  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Football).'  
      WHEN 'CS' THEN N'占成数不正确(于美式足球).'  
      WHEN 'CT' THEN N'佔成數不正確(於美式足球).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬาอเมริกันฟุตบอล).'  
      WHEN 'J' THEN N'Wrong position taking (for Football).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (풋볼).'  
      ELSE N'Wrong position taking (for Football).'  
    END  
 RETURN  
END  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 1 AS bettype, 3 AS sporttype, @v3apositiontaking_1 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 2 AS bettype, 3 AS sporttype, @v3apositiontaking_2 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 3 AS bettype, 3 AS sporttype, @v3apositiontaking_3 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 20 AS bettype, 3 AS sporttype, @v3apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 13  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
  
  
--Tennis  
  
if   
 @v5apositiontaking_1  <0  
 OR @v5apositiontaking_2  <0  
 OR @v5apositiontaking_3  <0  
 OR @v5apositiontaking_20  <0    
 OR @v5apositiontaking_1  >0.9  
 OR @v5apositiontaking_2  >0.9  
 OR @v5apositiontaking_3  >0.9  
 OR @v5apositiontaking_20  >0.9  
   
BEGIN  
 SELECT @ErrCode = 8  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Tennis).'  
      WHEN 'CS' THEN N'占成数不正确(于网球).'  
      WHEN 'CT' THEN N'佔成數不正確(於網球).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬาเทนนิส).'  
      WHEN 'J' THEN N'Wrong position taking (for Tennis).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (테니스).'  
      ELSE N'Wrong position taking (for Tennis).'  
    END  
 RETURN  
END  
  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 1 AS bettype, 5 AS sporttype, @v5apositiontaking_1 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 2 AS bettype, 5 AS sporttype, @v5apositiontaking_2 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 3 AS bettype, 5 AS sporttype, @v5apositiontaking_3 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 20 AS bettype, 5 AS sporttype, @v5apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 15  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
   
--Baseball  
if   
 @v8apositiontaking_1  <0  
 OR @v8apositiontaking_3  <0  
 OR @v8apositiontaking_20  <0    
 OR @v8apositiontaking_1  >0.9  
 OR @v8apositiontaking_3  >0.9  
 OR @v8apositiontaking_20  >0.9  
   
BEGIN  
 SELECT @ErrCode =16  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Baseball).'  
      WHEN 'CS' THEN N'占成数不正确(于棒球).'  
      WHEN 'CT' THEN N'佔成數不正確(於棒球).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬาเบสบอล).'  
      WHEN 'J' THEN N'Wrong position taking (for Baseball).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (야구).'  
      ELSE N'Wrong position taking (for Baseball).'  
    END  
 RETURN  
END  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 1 AS bettype, 8 AS sporttype, @v8apositiontaking_1 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 3 AS bettype, 8 AS sporttype, @v8apositiontaking_3 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 20 AS bettype, 8 AS sporttype, @v8apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 18  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
  
  
--Golf  
if   
 @v10apositiontaking_1  <0  
 OR @v10apositiontaking_2  <0  
 OR @v10apositiontaking_3  <0  
 OR @v10apositiontaking_20  <0    
 OR @v10apositiontaking_1  >0.9  
 OR @v10apositiontaking_2  >0.9  
 OR @v10apositiontaking_3  >0.9  
 OR @v10apositiontaking_20  >0.9  
   
BEGIN  
 SELECT @ErrCode = 19  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Golf).'  
      WHEN 'CS' THEN N'占成数不正确(于高尔夫球).'  
      WHEN 'CT' THEN N'佔成數不正確(於高爾夫球).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬากอฟล์).'  
      WHEN 'J' THEN N'Wrong position taking (for Golf).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (골프).'  
      ELSE N'Wrong position taking (for Golf).'  
    END  
 RETURN  
END  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 1 AS bettype, 10 AS sporttype, @v10apositiontaking_1 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 2 AS bettype, 10 AS sporttype, @v10apositiontaking_2 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 3 AS bettype, 10 AS sporttype, @v10apositiontaking_3 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 20 AS bettype, 10 AS sporttype, @v10apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 21  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
  
  
--Motorsports  
if   
 @v11apositiontaking_1  <0  
 OR @v11apositiontaking_20  <0    
 OR @v11apositiontaking_1  >0.9  
 OR @v11apositiontaking_20  >0.9  
   
BEGIN  
 SELECT @ErrCode = 22  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Motorsports).'  
      WHEN 'CS' THEN N'占成数不正确(于赛车).'  
      WHEN 'CT' THEN N'佔成數不正確(於賽車).'  
      WHEN 'TH' THEN N'การกำหนดไม่ถูกต้อง (สำหรับกีฬารถแข่ง).'  
      WHEN 'J' THEN N'Wrong position taking (for Motorsports).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (모토스포츠).'  
      ELSE N'Wrong position taking (for Motorsports).'  
    END  
 RETURN  
END  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 1 AS bettype, 11 AS sporttype, @v11apositiontaking_1 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 20 AS bettype, 11 AS sporttype, @v11apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 24  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max SET by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
   
--Other sports  
if   
 @v99apositiontaking_1  <0  
 OR @v99apositiontaking_2  <0  
 OR @v99apositiontaking_3  <0  
 OR @v99apositiontaking_20  <0    
 OR @v99apositiontaking_1  >0.9  
 OR @v99apositiontaking_2  >0.9  
 OR @v99apositiontaking_3  >0.9  
 OR @v99apositiontaking_20  >0.9  
   
BEGIN  
 SELECT @ErrCode = 25  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Other sports).'  
      WHEN 'CS' THEN N'占成数不正确(于其他).'  
      WHEN 'CT' THEN N'佔成數不正確(於其他).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬาอื่นๆ).'  
      WHEN 'J' THEN N'Wrong position taking (for Other sports).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (기타 스포츠).'  
      ELSE N'Wrong position taking (for Other sports).'  
    END  
 RETURN  
END  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 1 AS bettype, 99 AS sporttype, @v99apositiontaking_1 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 2 AS bettype, 99 AS sporttype, @v99apositiontaking_2 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 3 AS bettype, 99 AS sporttype, @v99apositiontaking_3 AS apositiontaking, 0 AS alivepositiontaking  
  UNION ALL  SELECT 20 AS bettype, 99 AS sporttype, @v99apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 27  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
   
  
--HR Fixed Odds  
if   
 @v154apositiontaking_20  <0  
 OR @v154apositiontaking_20  >0.9  
   
BEGIN  
 SELECT @ErrCode = 25  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for HR Fixed Odds).'  
      WHEN 'CS' THEN N'占成数不正确(于赛马固定赔率).'  
      WHEN 'CT' THEN N'佔成數不正確(於賽馬固定賠率).'  
      WHEN 'TH' THEN N'Wrong position taking for (for HR Fixed Odds).'  
      WHEN 'J' THEN N'Wrong position taking (for HR Fixed Odds).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (경마 고정 배당률).'  
      ELSE N'Wrong position taking (for HR Fixed Odds).'  
    END  
 RETURN  
END  
  
--check a1<=a4 - Vinh  
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 20 AS bettype, 154 AS sporttype, @v154apositiontaking_20 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 27  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
--- SB2
  if   
 @v44apositiontaking_3  <0  
 OR @v44apositiontaking_3  >0.9  
   
BEGIN  
	 SELECT @ErrCode = 25  
	 SELECT @ErrMsg =  CASE @Language   
		  WHEN 'E' THEN 'Wrong position taking (for Muay Thai).'  
		  WHEN 'CS' THEN N'占成数不正确(于赛马固定赔率).'  
		  WHEN 'CT' THEN N'佔成數不正確(於賽馬固定賠率).'  
		  WHEN 'TH' THEN N'Wrong position taking for (for Muay Thai).'  
		  WHEN 'J' THEN N'Wrong position taking (for Muay Thai).'  
		  WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (경마 고정 배당률).'  
		  ELSE N'Wrong position taking (for  Muay Thai).'  
		END  
	 RETURN  
END  
  
 
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10))  
+ CASE WHEN b.sporttype=1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 THEN '-MaxLive: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) ELSE '' END + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 3 AS bettype, 44 AS sporttype, @v44apositiontaking_3 AS apositiontaking, 0 AS alivepositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND ((b.apositiontaking>scs.apositiontaking AND scs.islive = 0) OR (b.sporttype = 1 AND b.bettype IN (1,3,7,8) AND scs.islive = 1 AND b.alivepositiontaking>scs.apositiontaking))  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 27  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
--Mix Parlay Mixed Sports  
if   
 @v99apositiontaking_9  <0  
 OR @v99apositiontaking_9  >0.9  
BEGIN  
 SELECT @ErrCode = 28  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (for Mix Sports Parlay).'  
      WHEN 'CS' THEN N'占成数不正确(供混合体育过关).'  
      WHEN 'CT' THEN N'佔成數不正確(供混合體育過關).'  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สำหรับกีฬาบอลชุด).'  
      WHEN 'J' THEN N'Wrong position taking (for Mix Sports Parlay).'  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (for Mix Sports Parlay).'  
      ELSE N'Wrong position taking (for Mix Sports Parlay).'  
    END  
 RETURN  
END  
  
--check a1<=a4   
SELECT @ErrType = ''  
SELECT @ErrType = @ErrType + sportname + '-'+ typenamee + '-Max: '+ CAST((scs.apositiontaking) AS VARCHAR(10)) + '<br>'  
FROM custinfo AS c WITH (NOLOCK) INNER JOIN dep_custsetting AS scs WITH (NOLOCK) ON c.srecommend = scs.custid INNER JOIN   
 (  
     SELECT 9 AS bettype, 99 AS sporttype, @v99apositiontaking_9 AS apositiontaking  
 ) AS b ON scs.sporttype=b.sporttype AND scs.bettype = b.bettype  
 INNER JOIN @tmp_Sports sports ON b.sporttype = sports.sporttype  
 INNER JOIN @tmp_Bettype bettype ON b.bettype = bettype.typeid  
WHERE c.custid = @recommend AND b.apositiontaking>scs.apositiontaking  
if @ErrType <>''  
BEGIN  
 SELECT @ErrCode = 30  
 SELECT @ErrMsg =  CASE @Language   
      WHEN 'E' THEN 'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'CS' THEN N'占成数不正确(公司设给最高占成).<br>'+@ErrType  
      WHEN 'CT' THEN N'佔成數不正確(公司設給最高佔成).<br>'+@ErrType  
      WHEN 'TH' THEN N'การกำหนดจำนวนเงินไม่ถูกต้อง (สูงสุด  อ้างอิงจากข้อมูลบริษัท).<br>'+@ErrType  
      WHEN 'J' THEN N'Wrong position taking (max set by company).<br>'+@ErrType  
      WHEN 'KO' THEN N'거래 조건이 잘못 되었습니다 (ibc가 설정한 최대 값).<br>'+@ErrType  
      ELSE N'Wrong position taking (max set by company).<br>'+@ErrType  
    END  
 RETURN  
END  
  
  
  
  
  
  
  
  
  
  
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  
  
--m1,s1,u1,i1,um1,im1  
SELECT @mpositiontaking_1 = mpositiontaking, @old_apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=1 and islive = 0  
SELECT @mlivepositiontaking_1 = mpositiontaking, @old_alivepositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=1 and islive = 1  
SELECT @mpositiontaking_3 = mpositiontaking, @old_apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=1 and islive= 0  
SELECT @mlivepositiontaking_3 = mpositiontaking, @old_alivepositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=1 and islive = 1  
SELECT @mpositiontaking_7 = mpositiontaking, @old_apositiontaking_7 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=7 AND sporttype=1 AND islive = 0  
SELECT @mlivepositiontaking_7 = mpositiontaking, @old_alivepositiontaking_7 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=7 AND sporttype=1 AND islive = 1  
SELECT @mpositiontaking_8 = mpositiontaking, @old_apositiontaking_8 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=8 AND sporttype=1 AND islive = 0  
SELECT @mlivepositiontaking_8 = mpositiontaking, @old_alivepositiontaking_8 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=8 AND sporttype=1 AND islive = 1  
  
SELECT @mpositiontaking_2 = mpositiontaking, @old_apositiontaking_2 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=2 AND sporttype=1  
SELECT @mpositiontaking_4 = mpositiontaking, @old_apositiontaking_4 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=4 AND sporttype=1  
SELECT @mpositiontaking_5 = mpositiontaking, @old_apositiontaking_5 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=5 AND sporttype=1  
SELECT @mpositiontaking_6 = mpositiontaking, @old_apositiontaking_6 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=6 AND sporttype=1  
SELECT @mpositiontaking_9 = mpositiontaking, @old_apositiontaking_9 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=9 AND sporttype=1  
SELECT @mpositiontaking_10 = mpositiontaking, @old_apositiontaking_10 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=10 AND sporttype=1  
  
SELECT @v2mpositiontaking_1 = mpositiontaking, @old_v2apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=2  
SELECT @v2mpositiontaking_2 = mpositiontaking, @old_v2apositiontaking_2 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=2 AND sporttype=2  
SELECT @v2mpositiontaking_3 = mpositiontaking, @old_v2apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=2  
SELECT @v2mpositiontaking_7 = mpositiontaking, @old_v2apositiontaking_7 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=7 AND sporttype=2  
SELECT @v2mpositiontaking_8 = mpositiontaking, @old_v2apositiontaking_8 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=8 AND sporttype=2  
SELECT @v2mpositiontaking_20 = mpositiontaking, @old_v2apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=2  
  
SELECT @v3mpositiontaking_1 = mpositiontaking,  @old_v3apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=3  
SELECT @v3mpositiontaking_2 = mpositiontaking,  @old_v3apositiontaking_2 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=2 AND sporttype=3  
SELECT @v3mpositiontaking_3 = mpositiontaking,  @old_v3apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=3  
SELECT @v3mpositiontaking_20 = mpositiontaking, @old_v3apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=3  
  
SELECT @v5mpositiontaking_1 = mpositiontaking, @old_v5apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=5  
SELECT @v5mpositiontaking_2 = mpositiontaking,  @old_v5apositiontaking_2 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=2 AND sporttype=5  
SELECT @v5mpositiontaking_3 = mpositiontaking,  @old_v5apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=5  
SELECT @v5mpositiontaking_20 = mpositiontaking, @old_v5apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=5  
  
SELECT @v8mpositiontaking_1 = mpositiontaking, @old_v8apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=8  
SELECT @v8mpositiontaking_3 = mpositiontaking, @old_v8apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=8  
SELECT @v8mpositiontaking_20 = mpositiontaking,@old_v8apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=8  
  
SELECT @v10mpositiontaking_1 = mpositiontaking, @old_v10apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=10  
SELECT @v10mpositiontaking_2 = mpositiontaking, @old_v10apositiontaking_2 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=2 AND sporttype=10  
SELECT @v10mpositiontaking_3 = mpositiontaking, @old_v10apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=10  
SELECT @v10mpositiontaking_20 = mpositiontaking, @old_v10apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=10  
  
SELECT @v11mpositiontaking_1 = mpositiontaking, @old_v11apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=11  
SELECT @v11mpositiontaking_20 = mpositiontaking, @old_v11apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=11  
  
SELECT @v99mpositiontaking_1 = mpositiontaking, @old_v99apositiontaking_1 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=1 AND sporttype=99  
SELECT @v99mpositiontaking_2 = mpositiontaking, @old_v99apositiontaking_2 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=2 AND sporttype=99  
SELECT @v99mpositiontaking_3 = mpositiontaking, @old_v99apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=99  
SELECT @v99mpositiontaking_9 = mpositiontaking, @old_v99apositiontaking_9 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=9 AND sporttype=99  
SELECT @v99mpositiontaking_20 = mpositiontaking, @old_v99apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=99  
  
--HR Fixed Odds  
SELECT @v154mpositiontaking_20 = mpositiontaking, @old_v154apositiontaking_20 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=20 AND sporttype=154  
--SB2  
SELECT @v44mpositiontaking_3 = mpositiontaking, @old_v44apositiontaking_3 = apositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @custid AND bettype=3 AND sporttype=44    
--s3,m3,u3,i3  
SELECT @mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=1 AND islive = 0  
SELECT @malivepositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=1 AND islive = 1  
SELECT @mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=1 AND islive = 0  
SELECT @malivepositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=1 AND islive = 1  
SELECT @mapositiontaking_7_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=7 AND sporttype=1 AND islive = 0  
SELECT @malivepositiontaking_7_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=7 AND sporttype=1 AND islive = 1  
SELECT @mapositiontaking_8_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=8 AND sporttype=1 AND islive = 0  
SELECT @malivepositiontaking_8_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=8 AND sporttype=1 AND islive = 1  
  
SELECT @mapositiontaking_2_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=2 AND sporttype=1  
SELECT @mapositiontaking_4_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=4 AND sporttype=1  
SELECT @mapositiontaking_5_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=5 AND sporttype=1  
SELECT @mapositiontaking_6_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=6 AND sporttype=1  
SELECT @mapositiontaking_9_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=9 AND sporttype=1  
SELECT @mapositiontaking_10_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=10 AND sporttype=1  
  
SELECT @v2mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=2  
SELECT @v2mapositiontaking_2_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=2 AND sporttype=2  
SELECT @v2mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=2  
SELECT @v2mapositiontaking_7_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=7 AND sporttype=2  
SELECT @v2mapositiontaking_8_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=8 AND sporttype=2  
SELECT @v2mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=2  
  
SELECT @v3mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=3  
SELECT @v3mapositiontaking_2_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=2 AND sporttype=3  
SELECT @v3mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=3  
SELECT @v3mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=3  
  
SELECT @v5mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=5  
SELECT @v5mapositiontaking_2_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=2 AND sporttype=5  
SELECT @v5mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=5  
SELECT @v5mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=5  
  
SELECT @v8mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=8  
SELECT @v8mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=8  
SELECT @v8mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=8  
  
SELECT @v10mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=10  
SELECT @v10mapositiontaking_2_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=2 AND sporttype=10  
SELECT @v10mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=10  
SELECT @v10mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=10  
  
SELECT @v11mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=11  
SELECT @v11mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=11  
  
SELECT @v99mapositiontaking_1_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=1 AND sporttype=99  
SELECT @v99mapositiontaking_2_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=2 AND sporttype=99  
SELECT @v99mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=99  
SELECT @v99mapositiontaking_9_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=9 AND sporttype=99  
SELECT @v99mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=99  
  
--HR Fixed Odds  
SELECT @v154mapositiontaking_20_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=20 AND sporttype=154  
---SB2
SELECT @v44mapositiontaking_3_max = mpositiontaking FROM dep_custsetting WITH (NOLOCK) WHERE custid = @mrecommend AND bettype=3 AND sporttype=44  
  
--a1=min(a1,m3)  
SELECT   
 @apositiontaking_1 = CASE WHEN @apositiontaking_1>@mapositiontaking_1_max THEN @mapositiontaking_1_max ELSE @apositiontaking_1 END,  
 @apositiontaking_2 = CASE WHEN @apositiontaking_2>@mapositiontaking_2_max THEN @mapositiontaking_2_max ELSE @apositiontaking_2 END,  
 @apositiontaking_3 = CASE WHEN @apositiontaking_3>@mapositiontaking_3_max THEN @mapositiontaking_3_max ELSE @apositiontaking_3 END,  
 @apositiontaking_4 = CASE WHEN @apositiontaking_4>@mapositiontaking_4_max THEN @mapositiontaking_4_max ELSE @apositiontaking_4 END,  
 @apositiontaking_5 = CASE WHEN @apositiontaking_5>@mapositiontaking_5_max THEN @mapositiontaking_5_max ELSE @apositiontaking_5 END,  
 @apositiontaking_6 = CASE WHEN @apositiontaking_6>@mapositiontaking_6_max THEN @mapositiontaking_6_max ELSE @apositiontaking_6 END,  
 @apositiontaking_7 = CASE WHEN @apositiontaking_7>@mapositiontaking_7_max THEN @mapositiontaking_7_max ELSE @apositiontaking_7 END,  
 @apositiontaking_8 = CASE WHEN @apositiontaking_8>@mapositiontaking_8_max THEN @mapositiontaking_8_max ELSE @apositiontaking_8 END,  
 @apositiontaking_9 = CASE WHEN @apositiontaking_9>@mapositiontaking_9_max THEN @mapositiontaking_9_max ELSE @apositiontaking_9 END,  
 @apositiontaking_10 = CASE WHEN @apositiontaking_10>@mapositiontaking_10_max THEN @mapositiontaking_10_max ELSE @apositiontaking_10 END,  
  
 @alivepositiontaking_1 = CASE WHEN @alivepositiontaking_1>@malivepositiontaking_1_max THEN @malivepositiontaking_1_max ELSE @alivepositiontaking_1 END,  
 @alivepositiontaking_3 = CASE WHEN @alivepositiontaking_3>@malivepositiontaking_3_max THEN @malivepositiontaking_3_max ELSE @alivepositiontaking_3 END,  
 @alivepositiontaking_7 = CASE WHEN @alivepositiontaking_7>@malivepositiontaking_7_max THEN @malivepositiontaking_7_max ELSE @alivepositiontaking_7 END,  
 @alivepositiontaking_8 = CASE WHEN @alivepositiontaking_8>@malivepositiontaking_8_max THEN @malivepositiontaking_8_max ELSE @alivepositiontaking_8 END,  
  
 @v2apositiontaking_1 = CASE WHEN @v2apositiontaking_1>@v2mapositiontaking_1_max THEN @v2mapositiontaking_1_max ELSE @v2apositiontaking_1 END,  
 @v2apositiontaking_2 = CASE WHEN @v2apositiontaking_2>@v2mapositiontaking_2_max THEN @v2mapositiontaking_2_max ELSE @v2apositiontaking_2 END,  
 @v2apositiontaking_3 = CASE WHEN @v2apositiontaking_3>@v2mapositiontaking_3_max THEN @v2mapositiontaking_3_max ELSE @v2apositiontaking_3 END,  
 @v2apositiontaking_7 = CASE WHEN @v2apositiontaking_7>@v2mapositiontaking_7_max THEN @v2mapositiontaking_7_max ELSE @v2apositiontaking_7 END,  
 @v2apositiontaking_8 = CASE WHEN @v2apositiontaking_8>@v2mapositiontaking_8_max THEN @v2mapositiontaking_8_max ELSE @v2apositiontaking_8 END,  
 @v2apositiontaking_20 = CASE WHEN @v2apositiontaking_20>@v2mapositiontaking_20_max THEN @v2mapositiontaking_20_max ELSE @v2apositiontaking_20 END,  
   
 @v3apositiontaking_1 = CASE WHEN @v3apositiontaking_1>@v3mapositiontaking_1_max THEN @v3mapositiontaking_1_max ELSE @v3apositiontaking_1 END,  
 @v3apositiontaking_2 = CASE WHEN @v3apositiontaking_2>@v3mapositiontaking_2_max THEN @v3mapositiontaking_2_max ELSE @v3apositiontaking_2 END,  
 @v3apositiontaking_3 = CASE WHEN @v3apositiontaking_3>@v3mapositiontaking_3_max THEN @v3mapositiontaking_3_max ELSE @v3apositiontaking_3 END,  
 @v3apositiontaking_20 = CASE WHEN @v3apositiontaking_20>@v3mapositiontaking_20_max THEN @v3mapositiontaking_20_max ELSE @v3apositiontaking_20 END,  
  
 @v5apositiontaking_1 = CASE WHEN @v5apositiontaking_1>@v5mapositiontaking_1_max THEN @v5mapositiontaking_1_max ELSE @v5apositiontaking_1 END,  
 @v5apositiontaking_2 = CASE WHEN @v5apositiontaking_2>@v5mapositiontaking_2_max THEN @v5mapositiontaking_2_max ELSE @v5apositiontaking_2 END,  
 @v5apositiontaking_3 = CASE WHEN @v5apositiontaking_3>@v5mapositiontaking_3_max THEN @v5mapositiontaking_3_max ELSE @v5apositiontaking_3 END,  
 @v5apositiontaking_20 = CASE WHEN @v5apositiontaking_20>@v5mapositiontaking_20_max THEN @v5mapositiontaking_20_max ELSE @v5apositiontaking_20 END,  
  
 @v8apositiontaking_1 = CASE WHEN @v8apositiontaking_1>@v8mapositiontaking_1_max THEN @v8mapositiontaking_1_max ELSE @v8apositiontaking_1 END,  
 @v8apositiontaking_3 = CASE WHEN @v8apositiontaking_3>@v8mapositiontaking_3_max THEN @v8mapositiontaking_3_max ELSE @v8apositiontaking_3 END,  
 @v8apositiontaking_20 = CASE WHEN @v8apositiontaking_20>@v8mapositiontaking_20_max THEN @v8mapositiontaking_20_max ELSE @v8apositiontaking_20 END,  
  
 @v10apositiontaking_1 = CASE WHEN @v10apositiontaking_1>@v10mapositiontaking_1_max THEN @v10mapositiontaking_1_max ELSE @v10apositiontaking_1 END,  
 @v10apositiontaking_2 = CASE WHEN @v10apositiontaking_2>@v10mapositiontaking_2_max THEN @v10mapositiontaking_2_max ELSE @v10apositiontaking_2 END,  
 @v10apositiontaking_3 = CASE WHEN @v10apositiontaking_3>@v10mapositiontaking_3_max THEN @v10mapositiontaking_3_max ELSE @v10apositiontaking_3 END,  
 @v10apositiontaking_20 = CASE WHEN @v10apositiontaking_20>@v10mapositiontaking_20_max THEN @v10mapositiontaking_20_max ELSE @v10apositiontaking_20 END,  
  
 @v11apositiontaking_1 = CASE WHEN @v11apositiontaking_1>@v11mapositiontaking_1_max THEN @v11mapositiontaking_1_max ELSE @v11apositiontaking_1 END,  
 @v11apositiontaking_20 = CASE WHEN @v11apositiontaking_20>@v11mapositiontaking_20_max THEN @v11mapositiontaking_20_max ELSE @v11apositiontaking_20 END,  
  
 @v99apositiontaking_1 = CASE WHEN @v99apositiontaking_1>@v99mapositiontaking_1_max THEN @v99mapositiontaking_1_max ELSE @v99apositiontaking_1 END,  
 @v99apositiontaking_2 = CASE WHEN @v99apositiontaking_2>@v99mapositiontaking_2_max THEN @v99mapositiontaking_2_max ELSE @v99apositiontaking_2 END,  
 @v99apositiontaking_3 = CASE WHEN @v99apositiontaking_3>@v99mapositiontaking_3_max THEN @v99mapositiontaking_3_max ELSE @v99apositiontaking_3 END,  
 @v99apositiontaking_9 = CASE WHEN @v99apositiontaking_9>@v99mapositiontaking_9_max THEN @v99mapositiontaking_9_max ELSE @v99apositiontaking_9 END,  
 @v99apositiontaking_20 = CASE WHEN @v99apositiontaking_20>@v99mapositiontaking_20_max THEN @v99mapositiontaking_20_max ELSE @v99apositiontaking_20 END,  
  
 --HR Fixed Odds  
 @v154apositiontaking_20 = CASE WHEN @v154apositiontaking_20>@v154mapositiontaking_20_max THEN @v154mapositiontaking_20_max ELSE @v154apositiontaking_20 END , 
  ---SB2 
 @v44apositiontaking_3 = CASE WHEN @v44apositiontaking_3>@v44mapositiontaking_3_max THEN @v44mapositiontaking_3_max ELSE @v44apositiontaking_3 END  
   
--a1=if(!im)if(m1+a1>m3,m3-m1)  
SELECT   
 @apositiontaking_1 = CASE WHEN @apositiontaking_1+@mpositiontaking_1>@mapositiontaking_1_max THEN @mapositiontaking_1_max-@mpositiontaking_1 ELSE @apositiontaking_1 END,  
 @apositiontaking_2 = CASE WHEN @apositiontaking_2+@mpositiontaking_2>@mapositiontaking_2_max THEN @mapositiontaking_2_max-@mpositiontaking_2 ELSE @apositiontaking_2 END,  
 @apositiontaking_3 = CASE WHEN @apositiontaking_3+@mpositiontaking_3>@mapositiontaking_3_max THEN @mapositiontaking_3_max-@mpositiontaking_3 ELSE @apositiontaking_3 END,  
 @apositiontaking_4 = CASE WHEN @apositiontaking_4+@mpositiontaking_4>@mapositiontaking_4_max THEN @mapositiontaking_4_max-@mpositiontaking_4 ELSE @apositiontaking_4 END,  
 @apositiontaking_5 = CASE WHEN @apositiontaking_5+@mpositiontaking_5>@mapositiontaking_5_max THEN @mapositiontaking_5_max-@mpositiontaking_5 ELSE @apositiontaking_5 END,  
 @apositiontaking_6 = CASE WHEN @apositiontaking_6+@mpositiontaking_6>@mapositiontaking_6_max THEN @mapositiontaking_6_max-@mpositiontaking_6 ELSE @apositiontaking_6 END,  
 @apositiontaking_7 = CASE WHEN @apositiontaking_7+@mpositiontaking_7>@mapositiontaking_7_max THEN @mapositiontaking_7_max-@mpositiontaking_7 ELSE @apositiontaking_7 END,  
 @apositiontaking_8 = CASE WHEN @apositiontaking_8+@mpositiontaking_8>@mapositiontaking_8_max THEN @mapositiontaking_8_max-@mpositiontaking_8 ELSE @apositiontaking_8 END,  
 @apositiontaking_9 = CASE WHEN @apositiontaking_9+@mpositiontaking_9>@mapositiontaking_9_max THEN @mapositiontaking_9_max-@mpositiontaking_9 ELSE @apositiontaking_9 END,  
 @apositiontaking_10 = CASE WHEN @apositiontaking_10+@mpositiontaking_10>@mapositiontaking_10_max THEN @mapositiontaking_10_max-@mpositiontaking_10 ELSE @apositiontaking_10 END,  
  
 @alivepositiontaking_1 = CASE WHEN @alivepositiontaking_1+@mlivepositiontaking_1>@malivepositiontaking_1_max THEN @malivepositiontaking_1_max-@mlivepositiontaking_1 ELSE @alivepositiontaking_1 END,  
 @alivepositiontaking_3 = CASE WHEN @alivepositiontaking_3+@mlivepositiontaking_3>@malivepositiontaking_3_max THEN @malivepositiontaking_3_max-@mlivepositiontaking_3 ELSE @alivepositiontaking_3 END,  
 @alivepositiontaking_7 = CASE WHEN @alivepositiontaking_7+@mlivepositiontaking_7>@malivepositiontaking_7_max THEN @malivepositiontaking_7_max-@mlivepositiontaking_7 ELSE @alivepositiontaking_7 END,  
 @alivepositiontaking_8 = CASE WHEN @alivepositiontaking_8+@mlivepositiontaking_8>@malivepositiontaking_8_max THEN @malivepositiontaking_8_max-@mlivepositiontaking_8 ELSE @alivepositiontaking_8 END,  
  
 @v2apositiontaking_1 = CASE WHEN @v2apositiontaking_1+@v2mpositiontaking_1>@v2mapositiontaking_1_max THEN @v2mapositiontaking_1_max-@v2mpositiontaking_1 ELSE @v2apositiontaking_1 END,  
 @v2apositiontaking_2 = CASE WHEN @v2apositiontaking_2+@v2mpositiontaking_2>@v2mapositiontaking_2_max THEN @v2mapositiontaking_2_max-@v2mpositiontaking_2 ELSE @v2apositiontaking_2 END,  
 @v2apositiontaking_3 = CASE WHEN @v2apositiontaking_3+@v2mpositiontaking_3>@v2mapositiontaking_3_max THEN @v2mapositiontaking_3_max-@v2mpositiontaking_3 ELSE @v2apositiontaking_3 END,  
 @v2apositiontaking_7 = CASE WHEN @v2apositiontaking_7+@v2mpositiontaking_7>@v2mapositiontaking_7_max THEN @v2mapositiontaking_7_max-@v2mpositiontaking_7 ELSE @v2apositiontaking_7 END,  
 @v2apositiontaking_8 = CASE WHEN @v2apositiontaking_8+@v2mpositiontaking_8>@v2mapositiontaking_8_max THEN @v2mapositiontaking_8_max-@v2mpositiontaking_8 ELSE @v2apositiontaking_8 END,  
 @v2apositiontaking_20 = CASE WHEN @v2apositiontaking_20+@v2mpositiontaking_20>@v2mapositiontaking_20_max THEN @v2mapositiontaking_20_max-@v2mpositiontaking_20 ELSE @v2apositiontaking_20 END,  
  
 @v3apositiontaking_1 = CASE WHEN @v3apositiontaking_1+@v3mpositiontaking_1>@v3mapositiontaking_1_max THEN @v3mapositiontaking_1_max-@v3mpositiontaking_1 ELSE @v3apositiontaking_1 END,  
 @v3apositiontaking_2 = CASE WHEN @v3apositiontaking_2+@v3mpositiontaking_2>@v3mapositiontaking_2_max THEN @v3mapositiontaking_2_max-@v3mpositiontaking_2 ELSE @v3apositiontaking_2 END,  
 @v3apositiontaking_3 = CASE WHEN @v3apositiontaking_3+@v3mpositiontaking_3>@v3mapositiontaking_3_max THEN @v3mapositiontaking_3_max-@v3mpositiontaking_3 ELSE @v3apositiontaking_3 END,  
 @v3apositiontaking_20 = CASE WHEN @v3apositiontaking_20+@v3mpositiontaking_20>@v3mapositiontaking_20_max THEN @v3mapositiontaking_20_max-@v3mpositiontaking_20 ELSE @v3apositiontaking_20 END,  
  
 @v5apositiontaking_1 = CASE WHEN @v5apositiontaking_1+@v5mpositiontaking_1>@v5mapositiontaking_1_max THEN @v5mapositiontaking_1_max-@v5mpositiontaking_1 ELSE @v5apositiontaking_1 END,  
 @v5apositiontaking_2 = CASE WHEN @v5apositiontaking_2+@v5mpositiontaking_2>@v5mapositiontaking_2_max THEN @v5mapositiontaking_2_max-@v5mpositiontaking_2 ELSE @v5apositiontaking_2 END,  
 @v5apositiontaking_3 = CASE WHEN @v5apositiontaking_3+@v5mpositiontaking_3>@v5mapositiontaking_3_max THEN @v5mapositiontaking_3_max-@v5mpositiontaking_3 ELSE @v5apositiontaking_3 END,  
 @v5apositiontaking_20 = CASE WHEN @v5apositiontaking_20+@v5mpositiontaking_20>@v5mapositiontaking_20_max THEN @v5mapositiontaking_20_max-@v5mpositiontaking_20 ELSE @v5apositiontaking_20 END,  
  
 @v8apositiontaking_1 = CASE WHEN @v8apositiontaking_1+@v8mpositiontaking_1>@v8mapositiontaking_1_max THEN @v8mapositiontaking_1_max-@v8mpositiontaking_1 ELSE @v8apositiontaking_1 END,  
 @v8apositiontaking_3 = CASE WHEN @v8apositiontaking_3+@v8mpositiontaking_3>@v8mapositiontaking_3_max THEN @v8mapositiontaking_3_max-@v8mpositiontaking_3 ELSE @v8apositiontaking_3 END,  
 @v8apositiontaking_20 = CASE WHEN @v8apositiontaking_20+@v8mpositiontaking_20>@v8mapositiontaking_20_max THEN @v8mapositiontaking_20_max-@v8mpositiontaking_20 ELSE @v8apositiontaking_20 END,  
  
 @v10apositiontaking_1 = CASE WHEN @v10apositiontaking_1+@v10mpositiontaking_1>@v10mapositiontaking_1_max THEN @v10mapositiontaking_1_max-@v10mpositiontaking_1 ELSE @v10apositiontaking_1 END,  
 @v10apositiontaking_2 = CASE WHEN @v10apositiontaking_2+@v10mpositiontaking_2>@v10mapositiontaking_2_max THEN @v10mapositiontaking_2_max-@v10mpositiontaking_2 ELSE @v10apositiontaking_2 END,  
 @v10apositiontaking_3 = CASE WHEN @v10apositiontaking_3+@v10mpositiontaking_3>@v10mapositiontaking_3_max THEN @v10mapositiontaking_3_max-@v10mpositiontaking_3 ELSE @v10apositiontaking_3 END,  
 @v10apositiontaking_20 = CASE WHEN @v10apositiontaking_20+@v10mpositiontaking_20>@v10mapositiontaking_20_max THEN @v10mapositiontaking_20_max-@v10mpositiontaking_20 ELSE @v10apositiontaking_20 END,  
  
 @v11apositiontaking_1 = CASE WHEN @v11apositiontaking_1+@v11mpositiontaking_1>@v11mapositiontaking_1_max THEN @v11mapositiontaking_1_max-@v11mpositiontaking_1 ELSE @v11apositiontaking_1 END,  
 @v11apositiontaking_20 = CASE WHEN @v11apositiontaking_20+@v11mpositiontaking_20>@v11mapositiontaking_20_max THEN @v11mapositiontaking_20_max-@v11mpositiontaking_20 ELSE @v11apositiontaking_20 END,  
  
 @v99apositiontaking_1 = CASE WHEN @v99apositiontaking_1+@v99mpositiontaking_1>@v99mapositiontaking_1_max THEN @v99mapositiontaking_1_max-@v99mpositiontaking_1 ELSE @v99apositiontaking_1 END,  
 @v99apositiontaking_2 = CASE WHEN @v99apositiontaking_2+@v99mpositiontaking_2>@v99mapositiontaking_2_max THEN @v99mapositiontaking_2_max-@v99mpositiontaking_2 ELSE @v99apositiontaking_2 END,  
 @v99apositiontaking_3 = CASE WHEN @v99apositiontaking_3+@v99mpositiontaking_3>@v99mapositiontaking_3_max THEN @v99mapositiontaking_3_max-@v99mpositiontaking_3 ELSE @v99apositiontaking_3 END,  
 @v99apositiontaking_9 = CASE WHEN @v99apositiontaking_9+@v99mpositiontaking_9>@v99mapositiontaking_9_max THEN @v99mapositiontaking_9_max-@v99mpositiontaking_9 ELSE @v99apositiontaking_9 END,  
 @v99apositiontaking_20 = CASE WHEN @v99apositiontaking_20+@v99mpositiontaking_20>@v99mapositiontaking_20_max THEN @v99mapositiontaking_20_max-@v99mpositiontaking_20 ELSE @v99apositiontaking_20 END,  
  
 --HR Fixed Odds  
 @v154apositiontaking_20 = CASE WHEN @v154apositiontaking_20+@v154mpositiontaking_20>@v154mapositiontaking_20_max THEN @v154mapositiontaking_20_max-@v154mpositiontaking_20 ELSE @v154apositiontaking_20 END  ,
 --SB2
 @v44apositiontaking_3 = CASE WHEN @v44apositiontaking_3+@v44mpositiontaking_3>@v44mapositiontaking_3_max THEN @v44mapositiontaking_3_max-@v44mpositiontaking_3 ELSE @v44apositiontaking_3 END  
  
   
  
SELECT   
 @apositiontaking_1 = CASE WHEN @apositiontaking_1<0 THEN 0 ELSE @apositiontaking_1 END,  
 @apositiontaking_2 = CASE WHEN @apositiontaking_2<0 THEN 0 ELSE @apositiontaking_2 END,  
 @apositiontaking_3 = CASE WHEN @apositiontaking_3<0 THEN 0 ELSE @apositiontaking_3 END,  
 @apositiontaking_4 = CASE WHEN @apositiontaking_4<0 THEN 0 ELSE @apositiontaking_4 END,  
 @apositiontaking_5 = CASE WHEN @apositiontaking_5<0 THEN 0 ELSE @apositiontaking_5 END,  
 @apositiontaking_6 = CASE WHEN @apositiontaking_6<0 THEN 0 ELSE @apositiontaking_6 END,  
 @apositiontaking_7 = CASE WHEN @apositiontaking_7<0 THEN 0 ELSE @apositiontaking_7 END,  
 @apositiontaking_8 = CASE WHEN @apositiontaking_8<0 THEN 0 ELSE @apositiontaking_8 END,  
 @apositiontaking_9 = CASE WHEN @apositiontaking_9<0 THEN 0 ELSE @apositiontaking_9 END,  
 @apositiontaking_10 = CASE WHEN @apositiontaking_10<0 THEN 0 ELSE @apositiontaking_10 END,  
  
 @alivepositiontaking_1 = CASE WHEN @alivepositiontaking_1<0 THEN 0 ELSE @alivepositiontaking_1 END,  
 @alivepositiontaking_3 = CASE WHEN @alivepositiontaking_3<0 THEN 0 ELSE @alivepositiontaking_3 END,  
 @alivepositiontaking_7 = CASE WHEN @alivepositiontaking_7<0 THEN 0 ELSE @alivepositiontaking_7 END,  
 @alivepositiontaking_8 = CASE WHEN @alivepositiontaking_8<0 THEN 0 ELSE @alivepositiontaking_8 END,  
  
 @v2apositiontaking_1 = CASE WHEN @v2apositiontaking_1<0 THEN 0 ELSE @v2apositiontaking_1 END,  
 @v2apositiontaking_2 = CASE WHEN @v2apositiontaking_2<0 THEN 0 ELSE @v2apositiontaking_2 END,  
 @v2apositiontaking_3 = CASE WHEN @v2apositiontaking_3<0 THEN 0 ELSE @v2apositiontaking_3 END,  
 @v2apositiontaking_7 = CASE WHEN @v2apositiontaking_7<0 THEN 0 ELSE @v2apositiontaking_7 END,  
 @v2apositiontaking_8 = CASE WHEN @v2apositiontaking_8<0 THEN 0 ELSE @v2apositiontaking_8 END,  
 @v2apositiontaking_20 = CASE WHEN @v2apositiontaking_20<0 THEN 0 ELSE @v2apositiontaking_20 END,  
  
 @v3apositiontaking_1 = CASE WHEN @v3apositiontaking_1<0 THEN 0 ELSE @v3apositiontaking_1 END,  
 @v3apositiontaking_2 = CASE WHEN @v3apositiontaking_2<0 THEN 0 ELSE @v3apositiontaking_2 END,  
 @v3apositiontaking_3 = CASE WHEN @v3apositiontaking_3<0 THEN 0 ELSE @v3apositiontaking_3 END,  
 @v3apositiontaking_20 = CASE WHEN @v3apositiontaking_20<0 THEN 0 ELSE @v3apositiontaking_20 END,  
  
 @v5apositiontaking_1 = CASE WHEN @v5apositiontaking_1<0 THEN 0 ELSE @v5apositiontaking_1 END,  
 @v5apositiontaking_2 = CASE WHEN @v5apositiontaking_2<0 THEN 0 ELSE @v5apositiontaking_2 END,  
 @v5apositiontaking_3 = CASE WHEN @v5apositiontaking_3<0 THEN 0 ELSE @v5apositiontaking_3 END,  
 @v5apositiontaking_20 = CASE WHEN @v5apositiontaking_20<0 THEN 0 ELSE @v5apositiontaking_20 END,  
  
 @v8apositiontaking_1 = CASE WHEN @v8apositiontaking_1<0 THEN 0 ELSE @v8apositiontaking_1 END,  
 @v8apositiontaking_3 = CASE WHEN @v8apositiontaking_3<0 THEN 0 ELSE @v8apositiontaking_3 END,  
 @v8apositiontaking_20 = CASE WHEN @v8apositiontaking_20<0 THEN 0 ELSE @v8apositiontaking_20 END,  
  
 @v10apositiontaking_1 = CASE WHEN @v10apositiontaking_1<0 THEN 0 ELSE @v10apositiontaking_1 END,  
 @v10apositiontaking_2 = CASE WHEN @v10apositiontaking_2<0 THEN 0 ELSE @v10apositiontaking_2 END,  
 @v10apositiontaking_3 = CASE WHEN @v10apositiontaking_3<0 THEN 0 ELSE @v10apositiontaking_3 END,  
 @v10apositiontaking_20 = CASE WHEN @v10apositiontaking_20<0 THEN 0 ELSE @v10apositiontaking_20 END,  
  
 @v11apositiontaking_1 = CASE WHEN @v11apositiontaking_1<0 THEN 0 ELSE @v11apositiontaking_1 END,  
 @v11apositiontaking_20 = CASE WHEN @v11apositiontaking_20<0 THEN 0 ELSE @v11apositiontaking_20 END,  
  
 @v99apositiontaking_1 = CASE WHEN @v99apositiontaking_1<0 THEN 0 ELSE @v99apositiontaking_1 END,  
 @v99apositiontaking_2 = CASE WHEN @v99apositiontaking_2<0 THEN 0 ELSE @v99apositiontaking_2 END,  
 @v99apositiontaking_3 = CASE WHEN @v99apositiontaking_3<0 THEN 0 ELSE @v99apositiontaking_3 END,  
 @v99apositiontaking_9 = CASE WHEN @v99apositiontaking_9<0 THEN 0 ELSE @v99apositiontaking_9 END,  
 @v99apositiontaking_20 = CASE WHEN @v99apositiontaking_20<0 THEN 0 ELSE @v99apositiontaking_20 END,  
  
 --HR Fixed Odds  
 @v154apositiontaking_20 = CASE WHEN @v154apositiontaking_20<0 THEN 0 ELSE @v154apositiontaking_20 END  ,
-- SB2
@v44apositiontaking_3 = CASE WHEN @v44apositiontaking_3<0 THEN 0 ELSE @v44apositiontaking_3 END  
  
  
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------  
---------------------------------------  
BEGIN TRANSACTION  
---------------------------------------  
  
UPDATE dep_custsetting WITH (ROWLOCK, UPDLOCK)  
SET  
 apositiontaking = CASE   
      WHEN sporttype = 1 AND bettype = 1 AND islive = 1 THEN @alivepositiontaking_1  
      WHEN sporttype = 1 AND bettype = 1 AND islive = 0 THEN @apositiontaking_1  
      WHEN sporttype = 1 AND bettype = 3 AND islive = 1 THEN @alivepositiontaking_3  
      WHEN sporttype = 1 AND bettype = 3 AND islive = 0 THEN @apositiontaking_3  
      WHEN sporttype = 1 AND bettype = 7 AND islive = 1 THEN @alivepositiontaking_7  
      WHEN sporttype = 1 AND bettype = 7 AND islive = 0 THEN @apositiontaking_7  
      WHEN sporttype = 1 AND bettype = 8 AND islive = 1 THEN @alivepositiontaking_8  
      WHEN sporttype = 1 AND bettype = 8 AND islive = 0 THEN @apositiontaking_8  
  
      WHEN sporttype = 1 AND bettype = 2 AND islive = 0 THEN @apositiontaking_2  
      WHEN sporttype = 1 AND bettype = 4 AND islive = 0 THEN @apositiontaking_4  
      WHEN sporttype = 1 AND bettype = 5 AND islive = 0 THEN @apositiontaking_5  
      WHEN sporttype = 1 AND bettype = 6 AND islive = 0 THEN @apositiontaking_6  
      WHEN sporttype = 1 AND bettype = 9 AND islive = 0 THEN @apositiontaking_9  
      WHEN sporttype = 1 AND bettype = 10 AND islive = 0 THEN @apositiontaking_10  
  
      WHEN sporttype = 2 AND bettype = 1 THEN @v2apositiontaking_1  
      WHEN sporttype = 2 AND bettype = 2 THEN @v2apositiontaking_2  
      WHEN sporttype = 2 AND bettype = 3 THEN @v2apositiontaking_3  
      WHEN sporttype = 2 AND bettype = 7 THEN @v2apositiontaking_7  
      WHEN sporttype = 2 AND bettype = 8 THEN @v2apositiontaking_8  
      WHEN sporttype = 2 AND bettype = 20 THEN @v2apositiontaking_20  
        
      WHEN sporttype = 3 AND bettype = 1 THEN @v3apositiontaking_1  
      WHEN sporttype = 3 AND bettype = 2 THEN @v3apositiontaking_2  
      WHEN sporttype = 3 AND bettype = 3 THEN @v3apositiontaking_3  
      WHEN sporttype = 3 AND bettype = 20 THEN @v3apositiontaking_20  
            
      WHEN sporttype = 5 AND bettype = 1 THEN @v5apositiontaking_1  
      WHEN sporttype = 5 AND bettype = 2 THEN @v5apositiontaking_2  
      WHEN sporttype = 5 AND bettype = 3 THEN @v5apositiontaking_3  
      WHEN sporttype = 5 AND bettype = 20 THEN @v5apositiontaking_20  
  
      WHEN sporttype = 8 AND bettype = 1 THEN @v8apositiontaking_1  
      WHEN sporttype = 8 AND bettype = 3 THEN @v8apositiontaking_3  
      WHEN sporttype = 8 AND bettype = 20 THEN @v8apositiontaking_20  
  
      WHEN sporttype = 10 AND bettype = 1 THEN @v10apositiontaking_1  
      WHEN sporttype = 10 AND bettype = 2 THEN @v10apositiontaking_2  
      WHEN sporttype = 10 AND bettype = 3 THEN @v10apositiontaking_3  
      WHEN sporttype = 10 AND bettype = 20 THEN @v10apositiontaking_20  
      
      WHEN sporttype = 11 AND bettype = 1 THEN @v11apositiontaking_1  
      WHEN sporttype = 11 AND bettype = 20 THEN @v11apositiontaking_20  
        
      WHEN sporttype = 99 AND bettype = 1 THEN @v99apositiontaking_1  
      WHEN sporttype = 99 AND bettype = 2 THEN @v99apositiontaking_2  
      WHEN sporttype = 99 AND bettype = 3 THEN @v99apositiontaking_3  
      WHEN sporttype = 99 AND bettype = 9 THEN @v99apositiontaking_9  
      WHEN sporttype = 99 AND bettype = 20 THEN @v99apositiontaking_20  
  
      --HR Fixed Odds  
      WHEN sporttype = 154 AND bettype = 20 THEN @v154apositiontaking_20  
	-- SB2
	  WHEN sporttype = 44 AND bettype = 3 THEN @v44apositiontaking_3  
      ELSE  
       apositiontaking  
       END  
   
WHERE custid=@custid  
  
  
COMMIT TRANSACTION  
  
DECLARE @LogSPData VARCHAR(5000)  
DECLARE @TrackingValue2 VARCHAR(5000)  
   
SELECT @LogSPData = '<Lrf_CustomerUpdMemberBA_PositionTaking><info ' +  
'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +  
'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1)) + '" ' +  
'Language="'+ COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) + '" ' +  
'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" ' +  
'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(8000)),SPACE(1)) + '" />' +  
  
'<ag apt_1="'+ COALESCE(CAST(@apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_2="'+ COALESCE(CAST(@apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_3="'+ COALESCE(CAST(@apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_4="'+ COALESCE(CAST(@apositiontaking_4 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_5="'+ COALESCE(CAST(@apositiontaking_5 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_6="'+ COALESCE(CAST(@apositiontaking_6 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_7="'+ COALESCE(CAST(@apositiontaking_7 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_8="'+ COALESCE(CAST(@apositiontaking_8 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_9="'+ COALESCE(CAST(@apositiontaking_9 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_10="'+ COALESCE(CAST(@apositiontaking_10 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_1="'+ COALESCE(CAST(@alivepositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_3="'+ COALESCE(CAST(@alivepositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_7="'+ COALESCE(CAST(@alivepositiontaking_7 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_8="'+ COALESCE(CAST(@alivepositiontaking_8 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v2apt_1="'+ COALESCE(CAST(@v2apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_2="'+ COALESCE(CAST(@v2apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_3="'+ COALESCE(CAST(@v2apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_7="'+ COALESCE(CAST(@v2apositiontaking_7 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_8="'+ COALESCE(CAST(@v2apositiontaking_8 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_20="'+ COALESCE(CAST(@v2apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v3apt_1="'+ COALESCE(CAST(@v3apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v3apt_2="'+ COALESCE(CAST(@v3apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v3apt_3="'+ COALESCE(CAST(@v3apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v3apt_20="'+ COALESCE(CAST(@v3apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v5apt_1="'+ COALESCE(CAST(@v5apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v5apt_2="'+ COALESCE(CAST(@v5apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v5apt_3="'+ COALESCE(CAST(@v5apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v5apt_20="'+ COALESCE(CAST(@v5apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v8apt_1="'+ COALESCE(CAST(@v8apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v8apt_3="'+ COALESCE(CAST(@v8apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v8apt_20="'+ COALESCE(CAST(@v8apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v10apt_1="'+ COALESCE(CAST(@v10apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v10apt_2="'+ COALESCE(CAST(@v10apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v10apt_3="'+ COALESCE(CAST(@v10apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v10apt_20="'+ COALESCE(CAST(@v10apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v11apt_1="'+ COALESCE(CAST(@v11apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v11apt_20="'+ COALESCE(CAST(@v11apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v99apt_1="'+ COALESCE(CAST(@v99apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_2="'+ COALESCE(CAST(@v99apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_3="'+ COALESCE(CAST(@v99apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_9="'+ COALESCE(CAST(@v99apositiontaking_9 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_20="'+ COALESCE(CAST(@v99apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v44apt_3="'+ COALESCE(CAST(@v44apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v154apt_20="'+ COALESCE(CAST(@v154apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" /></Lrf_CustomerUpdMemberBA_PositionTaking>'  
 
  
  
  
SELECT @TrackingValue2 = '<Lrf_CustomerUpdMemberBA_PositionTaking><info ' +  
'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(50)),SPACE(1)) + '" ' +  
'IP="'+ COALESCE(CAST(@IP AS VARCHAR(40)),SPACE(1)) + '" ' +  
'Language="'+ COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) + '" ' +  
'ErrCode="'+ COALESCE(CAST(@ErrCode AS VARCHAR(50)),SPACE(1)) + '" ' +  
'ErrMsg="'+ COALESCE(CAST(@ErrMsg AS VARCHAR(8000)),SPACE(1)) + '" />' +  
  
'<ag apt_1="'+ COALESCE(CAST(@Old_apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_2="'+ COALESCE(CAST(@Old_apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_3="'+ COALESCE(CAST(@Old_apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_4="'+ COALESCE(CAST(@Old_apositiontaking_4 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_5="'+ COALESCE(CAST(@Old_apositiontaking_5 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_6="'+ COALESCE(CAST(@Old_apositiontaking_6 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_7="'+ COALESCE(CAST(@Old_apositiontaking_7 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_8="'+ COALESCE(CAST(@Old_apositiontaking_8 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_9="'+ COALESCE(CAST(@Old_apositiontaking_9 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'apt_10="'+ COALESCE(CAST(@Old_apositiontaking_10 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_1="'+ COALESCE(CAST(@Old_alivepositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_3="'+ COALESCE(CAST(@Old_alivepositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_7="'+ COALESCE(CAST(@Old_alivepositiontaking_7 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'alivept_8="'+ COALESCE(CAST(@Old_alivepositiontaking_8 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v2apt_1="'+ COALESCE(CAST(@Old_v2apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_2="'+ COALESCE(CAST(@Old_v2apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_3="'+ COALESCE(CAST(@Old_v2apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_7="'+ COALESCE(CAST(@Old_v2apositiontaking_7 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_8="'+ COALESCE(CAST(@Old_v2apositiontaking_8 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v2apt_20="'+ COALESCE(CAST(@Old_v2apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v3apt_1="'+ COALESCE(CAST(@Old_v3apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v3apt_2="'+ COALESCE(CAST(@Old_v3apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v3apt_3="'+ COALESCE(CAST(@Old_v3apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v3apt_20="'+ COALESCE(CAST(@Old_v3apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v5apt_1="'+ COALESCE(CAST(@Old_v5apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v5apt_2="'+ COALESCE(CAST(@Old_v5apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v5apt_3="'+ COALESCE(CAST(@Old_v5apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v5apt_20="'+ COALESCE(CAST(@Old_v5apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v8apt_1="'+ COALESCE(CAST(@Old_v8apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v8apt_3="'+ COALESCE(CAST(@Old_v8apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v8apt_20="'+ COALESCE(CAST(@Old_v8apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v10apt_1="'+ COALESCE(CAST(@Old_v10apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v10apt_2="'+ COALESCE(CAST(@Old_v10apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v10apt_3="'+ COALESCE(CAST(@Old_v10apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v10apt_20="'+ COALESCE(CAST(@Old_v10apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v11apt_1="'+ COALESCE(CAST(@Old_v11apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v11apt_20="'+ COALESCE(CAST(@Old_v11apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
  
'v99apt_1="'+ COALESCE(CAST(@Old_v99apositiontaking_1 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_2="'+ COALESCE(CAST(@Old_v99apositiontaking_2 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_3="'+ COALESCE(CAST(@Old_v99apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_9="'+ COALESCE(CAST(@Old_v99apositiontaking_9 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v99apt_20="'+ COALESCE(CAST(@Old_v99apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v44apt_3="'+ COALESCE(CAST(@Old_v44apositiontaking_3 AS VARCHAR(50)),SPACE(1)) + '" ' +  
'v154apt_20="'+ COALESCE(CAST(@Old_v154apositiontaking_20 AS VARCHAR(50)),SPACE(1)) + '" /></Lrf_CustomerUpdMemberBA_PositionTaking>'  
  
  
SET @endRun = GETDATE()  
SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)  
  
IF @IsAdmin = 0  
BEGIN  
 EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
 @UserID = @UserID,  
 @CustID = @CustID,  
 @ActionID = 2700,  
 @TrackingValue = @LogSPData,  
 @TrackingValue2 = @TrackingValue2,  
 @duration = @duration  
END  
ELSE  
BEGIN  
 EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
 @UserID = @UserID,  
 @CustID = @CustID,  
 @ActionID = 423,  
 @TrackingValue = @LogSPData,  
 @TrackingValue2 = @TrackingValue2,  
 @duration = @duration  
END  
GO