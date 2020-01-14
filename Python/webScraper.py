####################################################################################################################
#Deliverables:
#
#Scrape list of doctors at Kaiser Permanente, Northern California Region within the Redwood City Office.
#https://healthy.kaiserpermanente.org/northern-california/doctors-locations#/search-result
#
#Description:
#
#Please write a scraper with which you can scrape the following details. Get at least 50 Physician with following details. Show the code and implementation details.
#
#Physician Name: Stella Sarang Abhyankar, MD
#Physician Specialty: Hospital Medicine
#Practicing Address:
#Redwood City Medical Center
#1150 Veterans Blvd 
#Redwood City, CA 94063
#Phone: 650-299-2000
####################################################################################################################

# import libraries
from selenium import webdriver 
from selenium.common.exceptions import NoSuchElementException
import time

# unused libraries
#from selenium.webdriver.common.by import By
#from selenium.webdriver.support.ui import WebDriverWait
#from selenium.webdriver.support import expected_conditions
#from selenium.common.exceptions import StaleElementReferenceException


#class for data storage
class DoctorList:
  def __init__(self, name, specialty, address, phone):
    self.name = name
    self.specialty = specialty
    self.address = address
    self.phone = phone

#open web page
driver=webdriver.Chrome(executable_path="C:\chromedriver_win32\chromedriver.exe")
driver.get("https://healthy.kaiserpermanente.org/northern-california/doctors-locations#/search-result")
time.sleep(5)

#set default values for variables
resultsClassName = 'result-list'
linkNbr = 11
elementCSS = '#rowDownSide > div.column-6.columnLft > div > div.pagination > span:nth-child('+str(linkNbr)+') > a'
findNextButton = driver.find_element_by_css_selector(elementCSS)
results = driver.find_elements_by_css_selector('#doctors > div > div > search-result-doctor > div > div.detail-data')


#array for extracted data
data=[]
#variable to hold count of records in data array.
data_counter = len(data)

#create a function that loads the data on the current page. This allows me to recycle and simplify the code in my for loop
def grabRecords():
    for i in results:
                    
        find_doctor_name = i.find_element_by_class_name('doctorTitle')
        doctor_name = find_doctor_name.text
        
    
        find_specialty = i.find_element_by_class_name('specialtyMargin')
        specialty = find_specialty.text
        
    
        find_address = i.find_element_by_class_name('doctorAddress') 
        address = find_address.text    
    
        try:
            find_phone = i.find_element_by_class_name('doctorPhone')
            phone = find_phone.text 
        except NoSuchElementException:
            phone = "N/A"
               
        data.append(DoctorList(doctor_name,specialty,address,phone))
                                                       

#print some details that the loop is beginning and keep track of counts
print('Begin loop - Number of records in array', data_counter)

#requirement is to be able to pull at least 50 records, so we will loop through the code until our data counter is 50 or greater
while data_counter<50:
    grabRecords()
    data_counter = len(data)
    print('Inner loop - Number of records in array', data_counter)
    
	#since pages have 20 results, I didn't want to have to click the next button for no reason on the last run so I had a check if in the current page we will have enough records. If so I'll skip the next button click.
    if data_counter < 50:
        findNextButton.click()    
        time.sleep(10)
        
        #refresh elements to avoid StaleElementReferenceException
        results = driver.find_elements_by_css_selector('#doctors > div > div > search-result-doctor > div > div.detail-data')
        
       #Next button is child 11 on first page and 12 on subsequent pages so only increase once 
       #This will fail on last page because we don't check if element exists but the code never goes that far 
        if linkNbr == 11:
            linkNbr = linkNbr+1
        
		#refresh elements to avoid StaleElementReferenceException
        elementCSS = '#rowDownSide > div.column-6.columnLft > div > div.pagination > span:nth-child('+str(linkNbr)+') > a'
        findNextButton = driver.find_element_by_css_selector(elementCSS)
    else:
        break;

#print information regarding the loop finishing
print('End of while loop - Total records loaded into array', data_counter)
    
#Close driver since we have loaded all of our records into the data array
driver.close()

#print all data from the data array into console
for i in data:
    print("")
    print("Physician Name: ",i.name)
    print("Physician Specialty: ",i.specialty)
    print("Practicing Address: ")
    print(i.address)
    print("Phone: ",i.phone)
    print("___________________________")
