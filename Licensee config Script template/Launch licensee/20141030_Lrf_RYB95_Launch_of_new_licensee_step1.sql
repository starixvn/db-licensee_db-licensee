USE bodb_licensee

GO
/*
	Created: jim  
	Date: 2014-10-30
    Task : RYB95  - Launch of new licensee
    DB: dblic.bodb_licensee 
	
*/
-- DECLARE variable
DECLARE @licenseeid INT
DECLARE @AffectedDate datetime 
DECLARE @system AS TABLE (systemid INT )
DECLARE @product AS TABLE (productid INT )

-- init variable
SET @AffectedDate='2014-10-28'

SELECT @licenseeid=licenseeid
FROM dbo.licensees WITH (nolock)
WHERE licenseename='RYB95'

INSERT INTO @system(systemid)  
SELECT id AS systemid 
FROM dbo.systems WITH (nolock)
WHERE systemname IN ('Accounting','OA')

----RYB95 :Sportsbook, Number Game, Live Casino and RNG Casino , Virtual Sports
INSERT INTO  @product (productid)
SELECT productid
FROM dbo.Product3rd WITH (nolock)
WHERE productname IN ('Number Game','Live Casino','RNG Casino','Virtual Sports')


----- SET Official launch date
UPDATE licensees
SET AffectedDate=@AffectedDate
WHERE licenseeid=@licenseeid
--- SET EffectiveDate
UPDATE licenseeproduct3rd
SET EffectiveDate=@AffectedDate
WHERE licenseeid=@licenseeid
	AND productid IN (SELECT productid FROM @product)
-- SET active IN relevant system 
UPDATE 	systemlicensee
SET isactive=1 
WHERE licenseeid=@licenseeid
	and systemid IN (SELECT systemid FROM @system)	