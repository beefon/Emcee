import os
from xml.etree import ElementTree


def check_file_exists(path):
    if not os.path.exists(path):
        raise AssertionError("Expected to have file at: {path}".format(path=path))


def get_test_cases_from_xml_file(path):
    tree = ElementTree.parse(path)
    root = tree.getroot()
    cases = []
    for case in root.findall('.//testcase'):
        if not case.findall('skipped'):
            case_dict = case.attrib.copy()
            if len(case):
                for child in case:
                    print("child: " + str(child))
                    case_dict[child.tag] = child.attrib.copy()
            cases.append(case_dict)
    return cases